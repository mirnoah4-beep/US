import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../services/chat_service.dart';
import '../services/storage_service.dart';
import 'chat_grouping.dart';
import 'chat_message.dart';
import 'chat_read_state.dart';

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
  /// My own read watermark, from chat/read_{me}. Drives the read receipt
  /// independently of the badge counter.
  DateTime? get myLastReadAt => _myLastReadAt;
  /// True only while the partner's typing doc is BOTH `isTyping` and fresh
  /// (≤ ~5 s old). A local timer flips this off at the stale mark even if
  /// Firestore never emits again, so a crashed phone can't leave it stuck.
  bool get partnerTyping => typingIsFresh(
        isTyping: _partnerTypingRaw,
        updatedAt: _partnerTypingAt,
        now: DateTime.now(),
      );
  /// Message ids hearted by me / by the partner. Two bounded doc listeners
  /// cover the whole thread — no per-message subscriptions.
  /// Images still being compressed/uploaded, newest first. They render as
  /// local bubbles ahead of the thread; a message document is only created
  /// once the upload has succeeded, so a failed upload never leaves a
  /// dangling message (or a push) behind.
  List<PendingUpload> get uploads => List.unmodifiable(_uploads);
  Set<String> get myHearts => _myHearts;
  Set<String> get partnerHearts => _partnerHearts;
  bool isHearted(String messageId) =>
      _myHearts.contains(messageId) || _partnerHearts.contains(messageId);
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
  DateTime? _myLastReadAt;
  // Read-receipt write guards: the newest boundary we already wrote for, and
  // whether a markRead write is currently awaiting the server.
  DateTime? _lastMarkedBoundary;
  bool _markReadInFlight = false;

  // Typing: writer throttle + reader state and stale-expiry timer.
  final TypingThrottle _typingThrottle = TypingThrottle();
  bool _partnerTypingRaw = false;
  DateTime? _partnerTypingAt;
  Timer? _typingExpiry;

  Set<String> _myHearts = const {};
  Set<String> _partnerHearts = const {};
  final List<PendingUpload> _uploads = [];

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partnerTypingSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _myHeartsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partnerHeartsSub;

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
        _partnerTypingSub?.cancel();
        _partnerTypingSub = null;
        _partnerHeartsSub?.cancel();
        _partnerHeartsSub = null;
        _partnerTypingRaw = false;
        _partnerTypingAt = null;
        _partnerHearts = const {};
        if (partner.isNotEmpty) {
          _subscribePartnerRead(coupleId, partner);
          _subscribePartnerTyping(coupleId, partner);
          _subscribeHearts(coupleId, partner);
        }
      }
      if (_liveSub == null && _uid.isNotEmpty) {
        _subscribeMessages(coupleId);
        _subscribeMyRead(coupleId);
        _subscribeMyHearts(coupleId);
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
      final data = snap.data();
      final nextUnread = parseUnreadField(data?['unread']);
      final ts = data?['lastReadAt'];
      // A pending local write reports a null server timestamp; keep the last
      // known watermark rather than regressing to "never read".
      final nextRead = ts is Timestamp ? ts.toDate() : _myLastReadAt;
      var changed = false;
      if (nextUnread != _unread) { _unread = nextUnread; changed = true; }
      if (nextRead != _myLastReadAt) { _myLastReadAt = nextRead; changed = true; }
      if (changed) {
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

  /// Listens ONLY to the partner's typing doc. Freshness is re-evaluated on
  /// every read of [partnerTyping]; the expiry timer just makes sure the UI
  /// is told to re-read once the stale mark passes.
  void _subscribePartnerTyping(String coupleId, String partnerId) {
    _partnerTypingSub =
        ChatService.typingRef(coupleId, partnerId).snapshots().listen((snap) {
      final d = snap.data();
      _partnerTypingRaw = d?['isTyping'] == true;
      final ts = d?['updatedAt'];
      _partnerTypingAt = ts is Timestamp ? ts.toDate() : null;
      _typingExpiry?.cancel();
      if (_partnerTypingRaw && _partnerTypingAt != null) {
        final remaining = typingStaleAfter -
            DateTime.now().difference(_partnerTypingAt!) +
            const Duration(milliseconds: 100);
        _typingExpiry = Timer(
          remaining.isNegative ? Duration.zero : remaining,
          notifyListeners,
        );
      }
      notifyListeners();
    }, onError: _reportStreamError('partnerTyping'));
  }

  Set<String> _heartsFrom(DocumentSnapshot<Map<String, dynamic>> snap) =>
      (snap.data() ?? const {})
          .entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toSet();

  void _subscribeMyHearts(String coupleId) {
    _myHeartsSub = ChatService.heartsRef(coupleId, _uid).snapshots().listen((snap) {
      _myHearts = _heartsFrom(snap);
      notifyListeners();
    }, onError: _reportStreamError('myHearts'));
  }

  void _subscribeHearts(String coupleId, String partnerId) {
    _partnerHeartsSub =
        ChatService.heartsRef(coupleId, partnerId).snapshots().listen((snap) {
      _partnerHearts = _heartsFrom(snap);
      notifyListeners();
    }, onError: _reportStreamError('partnerHearts'));
  }

  void _recompute() {
    _messages = mergeMessages(_live, _older);
    notifyListeners();
  }

  void _resetCouple() {
    // Best-effort: clear my typing flag before tearing down. Correctness does
    // not depend on this write — readers expire stale docs on their own.
    _stopTypingWrite();
    _coupleSub?.cancel();
    _liveSub?.cancel();
    _readSub?.cancel();
    _partnerReadSub?.cancel();
    _partnerTypingSub?.cancel();
    _myHeartsSub?.cancel();
    _partnerHeartsSub?.cancel();
    _typingExpiry?.cancel();
    _coupleSub = null;
    _liveSub = null;
    _readSub = null;
    _partnerReadSub = null;
    _partnerTypingSub = null;
    _myHeartsSub = null;
    _partnerHeartsSub = null;
    _typingExpiry = null;
    _typingThrottle.reset();
    _partnerTypingRaw = false;
    _partnerTypingAt = null;
    _myHearts = const {};
    _partnerHearts = const {};
    _coupleId = '';
    _partnerId = '';
    _live = const [];
    _older.clear();
    _messages = const [];
    _oldestDoc = null;
    _hasMore = true;
    _unread = 0;
    _partnerLastReadAt = null;
    _myLastReadAt = null;
    _lastMarkedBoundary = null;
    _markReadInFlight = false;
    _uploads.clear();
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
    if (!visible) _stopTypingWrite();
    _maybeMarkRead();
  }

  void _setForeground(bool fg) {
    if (_foreground == fg) return;
    _foreground = fg;
    if (!fg) _stopTypingWrite();
    _maybeMarkRead();
  }

  // ── Typing writer ────────────────────────────────────────────────────────

  /// Called on every composer change. Writes are throttled by
  /// [TypingThrottle]: one on each true↔false transition, then a refresh at
  /// most every ~2.5 s while typing continues. Plain keystrokes in between
  /// cost nothing.
  void onComposerChanged(String text) {
    if (_coupleId.isEmpty || _uid.isEmpty || _partnerId.isEmpty) return;
    final typing = text.trim().isNotEmpty;
    if (!_typingThrottle.shouldWrite(typing, DateTime.now())) return;
    _writeTyping(typing);
  }

  /// Sends `false` if the last written state was `true`. Used on send, tab
  /// leave, background, couple change and dispose.
  void _stopTypingWrite() {
    if (!_typingThrottle.lastSentState) return;
    if (_coupleId.isEmpty || _uid.isEmpty) {
      _typingThrottle.reset();
      return;
    }
    _typingThrottle.shouldWrite(false, DateTime.now()); // records the transition
    _writeTyping(false);
  }

  void _writeTyping(bool typing) {
    unawaited(ChatService.setTyping(_coupleId, _uid, typing).catchError(
      (Object e, StackTrace st) {
        FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat setTyping');
      },
    ));
  }

  // ── Hearts ───────────────────────────────────────────────────────────────

  /// Toggles MY heart on a message. Each member controls only their own
  /// reaction; the partner's is read-only here and rules enforce the same.
  Future<void> toggleHeart(String messageId) async {
    if (_coupleId.isEmpty || _uid.isEmpty || messageId.isEmpty) return;
    final on = !_myHearts.contains(messageId);
    // Optimistic local update; the listener will confirm or revert.
    _myHearts = on
        ? {..._myHearts, messageId}
        : ({..._myHearts}..remove(messageId));
    notifyListeners();
    try {
      await ChatService.setHeart(_coupleId, _uid, messageId, on);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat setHeart');
    }
  }

  /// Advances my read watermark / clears my badge — but only while the chat
  /// is really visible (tab active AND app foregrounded).
  ///
  /// The read receipt is decided from the MESSAGES, not the badge counter:
  /// if a server-confirmed incoming message is newer than my watermark, it is
  /// marked read even when `unread` is still 0 because the Cloud Function
  /// increment has not arrived yet. The counter is a second, independent
  /// trigger so the badge always clears. Guards dedupe repeated snapshot
  /// emissions so a single new message costs a single write.
  void _maybeMarkRead() {
    if (_coupleId.isEmpty || _uid.isEmpty) return;
    final boundary = unreadBoundary(
      newestFirst: _messages,
      myUid: _uid,
      myLastReadAt: _myLastReadAt,
    );
    final go = shouldMarkRead(
      tabVisible: _tabVisible,
      foreground: _foreground,
      boundary: boundary,
      unread: _unread,
      lastMarkedBoundary: _lastMarkedBoundary,
      inFlight: _markReadInFlight,
    );
    if (!go) return;
    if (boundary != null) _lastMarkedBoundary = boundary;
    _markReadInFlight = true;
    ChatService.markRead(_coupleId, _uid).catchError((Object e, StackTrace st) {
      // Allow a retry on the next trigger if this write failed.
      _lastMarkedBoundary = null;
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'chat markRead');
    }).whenComplete(() => _markReadInFlight = false);
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
    _stopTypingWrite();
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

  // ── Images ───────────────────────────────────────────────────────────────

  /// Uploads a picked image and then writes an `image` message. Upload
  /// first, message second: the fan-out (unread bump + push) fires on the
  /// message document, so it must never exist without its file.
  Future<void> sendImage(XFile picked) async {
    if (_coupleId.isEmpty || _uid.isEmpty || _partnerId.isEmpty) return;
    final id = ChatService.newMessageId(_coupleId);
    final upload = PendingUpload(id: id, localPath: picked.path, file: picked);
    _uploads.insert(0, upload);
    notifyListeners();
    await _runUpload(upload);
  }

  Future<void> retryUpload(String id) async {
    final u = _uploads.where((u) => u.id == id).firstOrNull;
    if (u == null || u.status == UploadStatus.uploading) return;
    u.status = UploadStatus.uploading;
    u.error = null;
    notifyListeners();
    await _runUpload(u);
  }

  void removeUpload(String id) {
    _uploads.removeWhere((u) => u.id == id && u.status != UploadStatus.uploading);
    notifyListeners();
  }

  Future<void> _runUpload(PendingUpload u) async {
    final coupleId = _coupleId;
    final uid = _uid;
    final path = 'couples/$coupleId/chatImages/${u.id}.jpg';
    try {
      final r = await StorageService.uploadChatImage(coupleId, u.id, u.file);
      try {
        // The document write may itself queue offline; that is fine — the
        // file is already safely in Storage.
        await ChatService.sendImage(
          coupleId, uid, u.id,
          storagePath: r.storagePath, width: r.width, height: r.height,
        );
      } catch (e) {
        // Storage succeeded but the message did not — reported as its own
        // step, never folded into a generic "could not send".
        throw ChatImageSendException(ChatImageStep.firestore, e,
            path: r.storagePath, bytes: r.bytes, contentType: 'image/jpeg');
      }
      _stopTypingWrite();
      _uploads.removeWhere((x) => x.id == u.id);
      notifyListeners();
    } catch (e, st) {
      final ex = e is ChatImageSendException
          ? e
          : ChatImageSendException(ChatImageStep.upload, e, path: path);
      u.status = UploadStatus.failed;
      u.error = ex.toString();
      u.diagnostic = ex.diagnostic;
      notifyListeners();

      // What state did the failure leave behind? (Answers "object exists?" /
      // "document exists?" without guessing.)
      final objectExists = await StorageService.chatImageExists(path);
      final docExists = await ChatService.messageExists(coupleId, u.id);

      if (kDebugMode) {
        debugPrint('[chatImage] FAILED $ex');
        debugPrint('[chatImage]   uid=$uid couple=$coupleId partner=$_partnerId');
        debugPrint('[chatImage]   storage object exists after failure: $objectExists');
        debugPrint('[chatImage]   firestore message exists after failure: $docExists');
      }
      final c = FirebaseCrashlytics.instance;
      await c.setCustomKey('chatImage.step', ex.step.name);
      await c.setCustomKey('chatImage.code', ex.code);
      await c.setCustomKey('chatImage.path', ex.path ?? path);
      await c.setCustomKey('chatImage.bytes', ex.bytes ?? -1);
      await c.setCustomKey('chatImage.contentType', ex.contentType ?? 'n/a');
      await c.setCustomKey('chatImage.objectExists', objectExists);
      await c.setCustomKey('chatImage.docExists', docExists);
      await c.recordError(ex.cause, st, reason: 'chat sendImage ${ex.step.name}: ${ex.code}');
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

enum UploadStatus { uploading, failed }

/// A local, not-yet-sent image message.
class PendingUpload {
  PendingUpload({required this.id, required this.localPath, required this.file});
  final String id;
  final String localPath;
  final XFile file;
  UploadStatus status = UploadStatus.uploading;
  String? error;
  /// `step · code` — safe to show; no URLs or tokens.
  String? diagnostic;
}
