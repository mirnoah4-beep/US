import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'date_idea.dart';
import 'moment_item.dart';
import '../services/firestore_service.dart';

class AppState extends ChangeNotifier {
  // ── Auth + identity ────────────────────────────────────────────────────────
  String _userId = '';
  String _coupleId = '';
  String _displayName = '';
  String _partnerName = '';
  String? userAvatarUrl;
  String? userAvatarPath;
  String? partnerAvatarUrl;
  String _language = 'no';

  String get userId => _userId;
  String get coupleId => _coupleId;
  String get displayName => _displayName;
  String get partnerName => _partnerName;
  String get language => _language;

  // ── UI state ───────────────────────────────────────────────────────────────
  bool hasChildren = false;
  int? pendingTabIndex;
  bool ideaSheetRequested = false;
  String? highlightMomentId;
  DateTime? coupleCreatedAt;
  String _partnerId = '';
  String _partnerEmail = '';
  DateTime? togetherSince;
  ({DateTime date, String proposedBy})? togetherSinceProposal;

  String get partnerId => _partnerId;
  String get partnerEmail => _partnerEmail;

  // ── Moments / ideas (still local; Firestore writes happen on logMoment) ───
  List<MomentItem> moments = buildInitialMoments();
  List<DateIdea> ideas = buildInitialIdeas();

  // ── Subscription ───────────────────────────────────────────────────────────
  String subscriptionTier = 'premium';

  // ── LastTime derived data ──────────────────────────────────────────────────
  Map<String, DateTime> _lastTimestamps = {};
  int _streakRecord = 0;
  int _momentsTotal = 0;

  int get streakRecord => _streakRecord;
  int get momentsTotal => _lastTimestamps.length;

  int get momentsThisMonthCount {
    final now = DateTime.now();
    return _lastTimestamps.values
        .where((ts) => ts.year == now.year && ts.month == now.month)
        .length;
  }

  int get momentsThisWeekCount {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _lastTimestamps.values.where((ts) => !ts.isBefore(weekStart)).length;
  }

  Set<int> get activeDaysThisWeek {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final active = <int>{};
    for (final ts in _lastTimestamps.values) {
      final day = DateTime(ts.year, ts.month, ts.day);
      if (!day.isBefore(weekStart) && day.isBefore(weekEnd)) {
        active.add(ts.weekday);
      }
    }
    return active;
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  int weeklyDates = 0;
  int monthlyDates = 2;
  int weeklyWalks = 1;
  int weeklyPhoneFreeTalks = 0;

  static const int weeklyDateGoal = 1;
  static const int monthlyDateGoal = 4;
  static const int weeklyWalkGoal = 1;
  static const int weeklyPhoneFreeTalkGoal = 1;

  // ── Readiness (first emission received per stream) ────────────────────────
  bool _userDocLoaded = false;
  bool _coupleDocLoaded = false;
  bool _partnerDocLoaded = false;
  bool _settingsLoaded = false;
  bool _lastTimeLoaded = false;

  /// True once every stream backing the initial UI has delivered its first
  /// snapshot, so the app can be revealed without content popping in late.
  bool get isReady {
    if (_userId.isEmpty || !_userDocLoaded) return false;
    if (_coupleId.isEmpty) return true;
    if (!_coupleDocLoaded || !_settingsLoaded || !_lastTimeLoaded) return false;
    if (_partnerId.isNotEmpty && !_partnerDocLoaded) return false;
    return true;
  }

  // ── Internal subscriptions ─────────────────────────────────────────────────
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _coupleSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _partnerSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _lastTimeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;

  AppState() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  // ── Auth listener ──────────────────────────────────────────────────────────

  void _onAuthChanged(User? user) {
    _cancelDataSubs();
    _userDocLoaded = false;
    _coupleDocLoaded = false;
    _partnerDocLoaded = false;
    _settingsLoaded = false;
    _lastTimeLoaded = false;
    if (user == null) {
      _userId = '';
      _coupleId = '';
      _displayName = '';
      _partnerName = '';
      _partnerEmail = '';
      partnerAvatarUrl = null;
      coupleCreatedAt = null;
      _partnerId = '';
      togetherSince = null;
      togetherSinceProposal = null;
      notifyListeners();
      return;
    }
    _userId = user.uid;
    _displayName = user.displayName ?? '';
    _subscribeUser(user.uid);
    notifyListeners();
  }

  void _subscribeUser(String uid) {
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!_userDocLoaded) {
        _userDocLoaded = true;
        notifyListeners();
      }
      if (!snap.exists) return;
      final d = snap.data()!;
      final newCoupleId = d['coupleId'] as String? ?? '';
      final rawName = d['displayName'] as String? ?? '';
      final selfEmail = d['email'] as String? ?? '';
      final newName = rawName.isNotEmpty
          ? rawName
          : (selfEmail.isNotEmpty ? selfEmail.split('@').first : _displayName);
      final newAvatar = d['avatarUrl'] as String? ?? '';
      final newLang = d['language'] as String? ?? 'no';

      bool changed = false;
      if (newName != _displayName) { _displayName = newName; changed = true; }
      if (newAvatar != userAvatarUrl) { userAvatarUrl = newAvatar.isEmpty ? null : newAvatar; changed = true; }
      if (newLang != _language) { _language = newLang; changed = true; }

      if (newCoupleId != _coupleId) {
        _coupleId = newCoupleId;
        changed = true;
        _coupleDocLoaded = false;
        _partnerDocLoaded = false;
        _settingsLoaded = false;
        _lastTimeLoaded = false;
        if (newCoupleId.isNotEmpty) {
          _subscribeCouple(newCoupleId);
        } else {
          _coupleSub?.cancel();
          _partnerSub?.cancel();
          _settingsSub?.cancel();
          _lastTimeSub?.cancel();
          _partnerName = '';
          _partnerEmail = '';
          partnerAvatarUrl = null;
          coupleCreatedAt = null;
          _partnerId = '';
          togetherSince = null;
          togetherSinceProposal = null;
        }
      }
      if (changed) notifyListeners();
    }, onError: (Object e) => debugPrint('[AppState] userStream error: $e'));
  }

  void _subscribeCouple(String coupleId) {
    _coupleSub?.cancel();
    _coupleSub = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .snapshots()
        .listen((snap) {
      if (!_coupleDocLoaded) {
        _coupleDocLoaded = true;
        notifyListeners();
      }
      if (!snap.exists) return;
      final d = snap.data()!;
      final members = List<String>.from(d['members'] as List? ?? []);
      final newPartnerId = members.firstWhere(
          (id) => id != _userId, orElse: () => '');
      final ts = d['createdAt'] as Timestamp?;
      final newCreatedAt = ts?.toDate();
      final tsT = d['togetherSince'] as Timestamp?;
      final newTogetherSince = tsT?.toDate();
      final proposalMap = d['togetherSinceProposal'] as Map<String, dynamic>?;
      final ({DateTime date, String proposedBy})? newProposal = proposalMap != null
          ? (date: (proposalMap['date'] as Timestamp).toDate(),
             proposedBy: proposalMap['proposedBy'] as String? ?? '')
          : null;
      final newStreakRecord = d['streakRecord'] as int? ?? 0;

      bool changed = false;
      if (newStreakRecord != _streakRecord) { _streakRecord = newStreakRecord; changed = true; }
      if (newPartnerId != _partnerId) {
        _partnerId = newPartnerId;
        changed = true;
        _partnerDocLoaded = false;
        if (newPartnerId.isNotEmpty) _subscribePartner(newPartnerId);
      }
      if (newCreatedAt != coupleCreatedAt) {
        coupleCreatedAt = newCreatedAt;
        changed = true;
      }
      if (newTogetherSince != togetherSince) {
        togetherSince = newTogetherSince;
        changed = true;
      }
      if (newProposal != togetherSinceProposal) {
        togetherSinceProposal = newProposal;
        changed = true;
      }
      if (changed) notifyListeners();
    }, onError: (Object e) {
      debugPrint('[AppState] coupleStream error: $e');
      final errStr = e.toString();
      if (errStr.contains('permission-denied') || errStr.contains('PERMISSION_DENIED')) {
        _coupleSub?.cancel();
        _partnerSub?.cancel();
        _settingsSub?.cancel();
        _lastTimeSub?.cancel();
        _coupleId = '';
        _partnerId = '';
        _partnerName = '';
        _partnerEmail = '';
        partnerAvatarUrl = null;
        coupleCreatedAt = null;
        togetherSince = null;
        togetherSinceProposal = null;
        notifyListeners();
      }
    });

    _subscribeSettings(coupleId);
    _subscribeLastTime(coupleId);
  }

  void _subscribePartner(String partnerId) {
    _partnerSub?.cancel();
    _partnerSub = FirebaseFirestore.instance
        .collection('users')
        .doc(partnerId)
        .snapshots()
        .listen((snap) {
      if (!_partnerDocLoaded) {
        _partnerDocLoaded = true;
        notifyListeners();
      }
      if (!snap.exists) return;
      final d = snap.data()!;
      final displayName = d['displayName'] as String? ?? '';
      final email = d['email'] as String? ?? '';
      final newName = displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email.split('@').first : '');
      final newEmail = email;
      final raw = d['avatarUrl'] as String? ?? '';
      final newAvatar = raw.isEmpty ? null : raw;
      bool changed = false;
      if (newName != _partnerName) { _partnerName = newName; changed = true; }
      if (newEmail != _partnerEmail) { _partnerEmail = newEmail; changed = true; }
      if (newAvatar != partnerAvatarUrl) { partnerAvatarUrl = newAvatar; changed = true; }
      if (changed) notifyListeners();
    }, onError: (Object e) => debugPrint('[AppState] partnerStream error: $e'));
  }

  void _subscribeSettings(String coupleId) {
    _settingsSub?.cancel();
    _settingsSub = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('settings')
        .doc('main')
        .snapshots()
        .listen((snap) {
      if (!_settingsLoaded) {
        _settingsLoaded = true;
        notifyListeners();
      }
      if (!snap.exists) return;
      final d = snap.data()!;
      final newParentMode = d['parentMode'] as bool? ?? false;
      final newTotal = d['momentsThisMonth'] as int? ?? 0;
      bool changed = false;
      if (newParentMode != hasChildren) { hasChildren = newParentMode; changed = true; }
      if (newTotal != _momentsTotal) { _momentsTotal = newTotal; changed = true; }
      if (changed) notifyListeners();
    }, onError: (Object e) => debugPrint('[AppState] settingsStream error: $e'));
  }

  void _subscribeLastTime(String coupleId) {
    _lastTimeSub?.cancel();
    _lastTimeSub = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('lastTime')
        .snapshots()
        .listen((snap) {
      _lastTimeLoaded = true;
      final newTimestamps = <String, DateTime>{};
      for (final doc in snap.docs) {
        final activityId = doc.id;
        final ts = doc.data()['lastDone'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        newTimestamps[activityId] = dt;
        final daysAgo = DateTime.now().difference(dt).inDays;
        final idx = moments.indexWhere((m) => m.id == activityId);
        if (idx != -1 && moments[idx].daysAgo != daysAgo) {
          moments[idx] = moments[idx].copyWith(daysAgo: daysAgo);
        }
      }
      _lastTimestamps = newTimestamps;
      notifyListeners();
    }, onError: (Object e) => debugPrint('[AppState] lastTimeStream error: $e'));
  }

  void _cancelDataSubs() {
    _userSub?.cancel();
    _coupleSub?.cancel();
    _partnerSub?.cancel();
    _settingsSub?.cancel();
    _lastTimeSub?.cancel();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    notifyListeners();
    if (_userId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({'displayName': name});
    }
  }

  void updateDisplayName(String name) {
    if (_displayName == name) return;
    _displayName = name;
    notifyListeners();
  }

  Future<void> setUserAvatarPath(String path) async {
    userAvatarPath = path;
    notifyListeners();
  }

  void setHasChildren(bool value) {
    hasChildren = value;
    notifyListeners();
  }

  void requestTabNavigation(int tabIndex, {String? highlightId}) {
    pendingTabIndex = tabIndex;
    highlightMomentId = highlightId;
    notifyListeners();
  }

  void consumeTabNavigation() {
    pendingTabIndex = null;
    notifyListeners();
  }

  void requestIdeaSheet() {
    ideaSheetRequested = true;
    notifyListeners();
  }

  void consumeIdeaSheet() {
    ideaSheetRequested = false;
  }

  void clearHighlight() {
    highlightMomentId = null;
    notifyListeners();
  }

  // ── Moments ────────────────────────────────────────────────────────────────

  List<MomentItem> get visibleMoments {
    if (hasChildren) return moments;
    return moments.where((m) => !m.parentModeOnly).toList();
  }

  List<DateIdea> get visibleIdeas {
    if (hasChildren) return ideas;
    return ideas.where((i) => !i.parentModeOnly).toList();
  }

  void logMoment(String momentId) {
    final index = moments.indexWhere((m) => m.id == momentId);
    if (index != -1) {
      moments[index] = moments[index].copyWith(daysAgo: 0);
      if (momentId == 'date_night' || momentId == 'home_date') {
        weeklyDates++;
        monthlyDates++;
      }
      if (momentId == 'walk') weeklyWalks++;
      if (momentId == 'phone_free') weeklyPhoneFreeTalks++;
    }
    // Optimistic timestamp update for weekly strip and stats
    _lastTimestamps[momentId] = DateTime.now();

    // Update streak record if current streak beats it
    final newStreak = streakWeeks;
    if (newStreak > _streakRecord) {
      _streakRecord = newStreak;
      if (_coupleId.isNotEmpty) {
        FirestoreService.updateStreakRecord(_coupleId, _streakRecord).catchError((_) {});
      }
    }

    notifyListeners();
    // Firestore write (fire and forget)
    if (_coupleId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('couples')
          .doc(_coupleId)
          .collection('lastTime')
          .doc(momentId)
          .set({'lastDone': FieldValue.serverTimestamp()}, SetOptions(merge: true))
          .catchError((_) {});
      FirebaseFirestore.instance
          .collection('couples')
          .doc(_coupleId)
          .collection('settings')
          .doc('main')
          .update({'momentsThisMonth': FieldValue.increment(1)})
          .catchError((_) {});
    }
  }

  void toggleFavorite(String ideaId) {
    final index = ideas.indexWhere((i) => i.id == ideaId);
    if (index != -1) {
      ideas[index].isFavorite = !ideas[index].isFavorite;
      notifyListeners();
    }
  }

  // ── Battery ────────────────────────────────────────────────────────────────

  int get batteryPercent {
    int score = 72;
    final dateNight = moments.firstWhere((m) => m.id == 'date_night');
    if (dateNight.daysAgo == 0) score += 5;
    return score.clamp(0, 100);
  }

  String get batteryStatusLine {
    final pct = batteryPercent;
    if (pct >= 80) return 'You\'re doing great! 💚';
    if (pct >= 65) return 'You\'re doing well! 💛';
    return 'Time to reconnect. 🤍';
  }

  String get batteryMessage {
    final pct = batteryPercent;
    if (pct >= 80) return 'Your connection is strong. Keep it up.';
    if (pct >= 65) return 'Recharge with small moments together.';
    return 'It\'s been a while. Plan something soon.';
  }

  MomentItem get lastDateMoment =>
      moments.firstWhere((m) => m.id == 'date_night');

  int get momentCountThisMonth =>
      moments.where((m) => m.daysAgo <= 30).length;

  int get streakWeeks {
    int streak = 0;
    for (int week = 0; week < 12; week++) {
      final minDay = week * 7;
      final maxDay = minDay + 6;
      final hasActivity =
          moments.any((m) => m.daysAgo >= minDay && m.daysAgo <= maxDay);
      if (hasActivity) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDataSubs();
    super.dispose();
  }
}
