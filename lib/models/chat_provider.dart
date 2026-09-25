import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';

import '../services/chat_service.dart';
import 'chat_message.dart';

/// State for the partner chat tab.
///
/// Follows the same auth → user doc → couple pattern as RemindersProvider so
/// it is self-contained. Live listeners are bounded on purpose:
///   - the newest page of messages (ChatService.pageSize)
///   - the couple doc (for the partner uid)
///   - my read doc (unread badge) and the partner's (the "seen" mark)
/// Older history is fetched page by page and never listened to.
class ChatProvider extends ChangeNotifier {
  ChatProvider() {
    _lifecycle = AppLifecycleListener(
      onShow: () => _setForeground(true),
      onResume: () => _setForeground(true),
      onHide: () => _setForeground(false),
      onPause: () => _setForeground(false),
    );
    _listenToAuth();
  }

  // ── Public state ─────────────────────────────────────────────────────────
  List<ChatMessage> get messages => _messages;
  int get unread => _unread;
  DateTime? get partnerLastReadAt => _partnerLastReadAt;
  String get coupleId => _coupleId;
  String get userId => _uid;
  String get partnerId => _partnerId;
  bool get hasPartner => _partnerId.isNotEmpty;
  bool get initialized => _initialized;
  bool get loadingOlder => _loadingOlder;
  bool get hasMore => _hasMore;
  bool get isFromCache => _isFromCache;
  String? get error => _error;

  // ── Internals ────────────────────────────────────────────────────────────
  String _uid = '';
  String _coupleId = '';
  String _partnerId = '';
  bool _initialized = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _isFromCache = false;
  String? _error;
  int _unread = 0;
  DateTime? _partnerLastReadAt;

  List<ChatMessage> _live = const [];
  final List<ChatMessage> _older = [];
  List<ChatMessage> _messages = const [];
  DocumentSnapshot<Map<String, dynamic>>? _oldestDoc;

  bool _tabVisible = false;
  bool _foreground = true;
  DateTime _lastSendAt = DateTime.fromMillisecondsSinceEpoch(0);

  late final AppLifecycleListener _lifecycle;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _coupleSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _liveSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _readSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partnerReadSub;

  /// Minimum gap between sends — a soft anti-spam guard that never blocks
  /// offline queueing (it is purely local).
  static const Duration sendThrottle = Duration(milliseconds: 400);

  // ── Wiring ───────────────────────────────────────────────────────────────

  void _listenToAuth() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSub?.cancel();
      if (user == null) {
        _uid = '';
        _resetCouple();
        _initialized = true;
        notifyListeners();
        return;
      }
      _uid = user.uid;
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snap) {
        final coupleId = snap.data()?['coupleId'] as String? ?? '';
        if (coupleId != _coupleId) {
          _resetCouple();
          _coupleId = coupleId;
          if (coupleId.isNotEmpty) _subscribeCouple(coupleId);
        }
        _initialized = true;
        notifyListeners();
      }, onError: _reportStreamError('user'));
    });
  }

  void _subscribeCouple(String coupleId) {
    _coupleSub = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .snapshots()
        .listen((snap) {
      final members = List<String>.from(snap.data()?['members'] as List? ?? []);
      final partner = members.firstWhere((m) => m != _uid, orElse: () => '');
      if (partner != _partnerId) {
        _partnerId = partner;
        _partnerReadSub?.cancel();
        _partnerReadSub = null;
        if (partner.isNotEmpty) _subscribePartnerRead(coupleId, partner);
      }
      if (_liveSub == null && _uid.isNotEmpty) {
        _subscribeMessages(coupleId);
        _subscribeMyRead(coupleId);
      }
      notifyListeners();
    }, onError: _reportStreamError('couple'));
  }

  void _subscribeMessages(String coupleId) {
    _liveSub = ChatService.newestQuery(coupleId)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _isFromCache = snap.metadata.isFromCache;
      _live = snap.docs
          .map(ChatMessage.fromDoc)
          .whereType<ChatMessage>()
          .toList(growable: false);
      // A short first page means there is nothing older to load.
      if (_older.isEmpty && snap.docs.length < ChatService.pageSize) {
        _hasMore = false;
      }
      if (_older.isEmpty && snap.docs.isNotEmpty) _oldestDoc = snap.docs.last;
      _error = null;
      _recompute();
      _maybeMarkRead();
    }, onError: (Object e, StackTrace st) {
      _error = e.toString();
      _reportStreamError('messages')(e, st);
      notifyListeners();
    });
  }

  void _subscribeMyRead(String coupleId) {
    _readSub = ChatService.readRef(coupleId, _uid).snapshots().listen((snap) {
      final n = snap.data()?['unread'];
      final next = n is num ? n.toInt() : 0;
      if (next != _unread) {
        _unread = next;
        notifyListeners();
        _maybeMarkRead();
      }
    }, onError: _reportStreamError('read'));
  }

  void _subscribePartnerRead(String coupleId, String partnerId) {
    _partnerReadSub =
        ChatService.readRef(coupleId, partnerId).snapshots().listen((snap) {
      final ts = snap.data()?['lastReadAt'];
      final next = ts is Timestamp ? ts.toDate() : null;
      if (next != _partnerLastReadAt) {
        _partnerLastReadAt = next;
        notifyListeners();
      }
    }, onError: _reportStreamError('partnerRead'));
  }

  void _recompute() {
    _messages = mergeMessages(_live, _older);
    notifyListeners();
  }

  void _resetCouple() {
    _coupleSub?.cancel();
    _liveSub?.cancel();
    _readSub?.cancel();
    _partnerReadSub?.cancel();
    _coupleSub = null;
    _liveSub = null;
    _readSub = null;
    _partnerReadSub = null;
    _coupleId = '';
    _partnerId = '';
    _live = const [];
    _older.clear();
    _messages = const [];
    _oldestDoc = null;
    _hasMore = true;
    _unread = 0;
    _partnerLastReadAt = null;
    _error = null;
  }

  void Function(Object, StackTrace) _reportStreamError(String which) =>
      (Object e, StackTrace st) {
        FirebaseCrashlytics.instance
            .recordError(e, st, reason: 'ChatProvider $which stream');
      };

  // ── Visibility / read state ──────────────────────────────────────────────

  /// Called by the tab shell when the Chat tab becomes (in)active.
  void setTabVisible(bool visible) {
    if (_tabVisible == visible) return;
    _tabVisible = visible;
    _maybeMarkRead();
  }

  void _setForeground(bool fg) {
    if (_foreground == fg) return;
    _foreground = fg;
    _maybeMarkRead();
  }

  bool get _isReallyVisible => _tabVisible && _foreground;

  /// Marks the chat read only when the user can actually see it, and only
  /// when there is something unread — so backgrounded devices never
  /// silently consume the badge.
  void _maybeMarkRead() {
    if (!_isReallyVisible || _coupleId.isEmpty || _uid.isEmpty) return;
    if (_unread == 0) return;
    ChatService.markRead(_coupleId, _uid).catchError((Object e, StackTrace st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat markRead');
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Loads the next page of older messages. Safe to call repeatedly.
  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMore || _coupleId.isEmpty) return;
    final after = _oldestDoc;
    if (after == null) {
      _hasMore = false;
      notifyListeners();
      return;
    }
    _loadingOlder = true;
    notifyListeners();
    try {
      final snap = await ChatService.fetchOlder(_coupleId, after);
      final page = snap.docs
          .map(ChatMessage.fromDoc)
          .whereType<ChatMessage>()
          .toList();
      _older.addAll(page);
      if (snap.docs.isNotEmpty) _oldestDoc = snap.docs.last;
      if (snap.docs.length < ChatService.pageSize) _hasMore = false;
      _recompute();
    } catch (e, st) {
      _error = e.toString();
      await FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat loadOlder');
    } finally {
      _loadingOlder = false;
      notifyListeners();
    }
  }

  /// Validates and sends a text message. Returns false when nothing was sent
  /// (empty, too long, throttled, or no couple) so the UI can react.
  Future<bool> sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > ChatService.maxTextLength) return false;
    if (_coupleId.isEmpty || _uid.isEmpty || _partnerId.isEmpty) return false;
    final now = DateTime.now();
    if (now.difference(_lastSendAt) < sendThrottle) return false;
    _lastSendAt = now;
    try {
      // Not awaited for completion semantics: with offline persistence the
      // write resolves only once the server acks, and the message already
      // shows locally via the listener.
      unawaited(ChatService.sendText(_coupleId, _uid, text).catchError(
        (Object e, StackTrace st) {
          _error = e.toString();
          notifyListeners();
          FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat sendText');
        },
      ));
      return true;
    } catch (e, st) {
      _error = e.toString();
      notifyListeners();
      await FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat sendText');
      return false;
    }
  }

  Future<bool> sendIdea(ChatIdea idea) async {
    if (_coupleId.isEmpty || _uid.isEmpty || _partnerId.isEmpty) return false;
    try {
      unawaited(ChatService.sendIdea(_coupleId, _uid, idea).catchError(
        (Object e, StackTrace st) {
          _error = e.toString();
          notifyListeners();
          FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat sendIdea');
        },
      ));
      return true;
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat sendIdea');
      return false;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _authSub?.cancel();
    _userSub?.cancel();
    _resetCouple();
    super.dispose();
  }
}
