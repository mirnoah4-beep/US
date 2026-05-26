import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'moment_item.dart';
import 'date_idea.dart';

class AppState extends ChangeNotifier {
  bool hasChildren = false;
  String? userAvatarPath;

  // Tab navigation + highlight
  int? pendingTabIndex;
  String? highlightMomentId;

  void requestTabNavigation(int tabIndex, {String? highlightId}) {
    pendingTabIndex = tabIndex;
    highlightMomentId = highlightId;
    notifyListeners();
  }

  void consumeTabNavigation() {
    pendingTabIndex = null;
    notifyListeners();
  }

  void clearHighlight() {
    highlightMomentId = null;
    notifyListeners();
  }

  AppState() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // TODO: replace with Firestore when backend ready
    hasChildren = prefs.getBool('parentMode') ?? false;
    userAvatarPath = prefs.getString('userAvatarPath');
    displayName = prefs.getString('userName') ?? 'Noah';
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    displayName = name;
    notifyListeners();
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
  }

  void updateDisplayName(String name) {
    if (displayName == name) return;
    displayName = name;
    notifyListeners();
  }

  Future<void> setUserAvatarPath(String path) async {
    userAvatarPath = path;
    notifyListeners();
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userAvatarPath', path);
  }
  // TODO: replace with real couple ID from Firebase Auth
  String get coupleId => 'couple_001';
  String get userId => 'user_001';
  String displayName = 'Noah';
  String get partnerName => 'Sarah';
  String subscriptionTier = 'premium';
  List<MomentItem> moments = buildInitialMoments();
  List<DateIdea> ideas = buildInitialIdeas();

  int weeklyDates = 0;
  int monthlyDates = 2;
  int weeklyWalks = 1;
  int weeklyPhoneFreeTalks = 0;

  static const int weeklyDateGoal = 1;
  static const int monthlyDateGoal = 4;
  static const int weeklyWalkGoal = 1;
  static const int weeklyPhoneFreeTalkGoal = 1;

  List<MomentItem> get visibleMoments {
    if (hasChildren) return moments;
    return moments.where((m) => !m.parentModeOnly).toList();
  }

  List<DateIdea> get visibleIdeas {
    if (hasChildren) return ideas;
    return ideas.where((i) => !i.parentModeOnly).toList();
  }

  void setHasChildren(bool value) {
    hasChildren = value;
    notifyListeners();
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
    notifyListeners();
  }

  void toggleFavorite(String ideaId) {
    final index = ideas.indexWhere((i) => i.id == ideaId);
    if (index != -1) {
      ideas[index].isFavorite = !ideas[index].isFavorite;
      notifyListeners();
    }
  }

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

  // Number of consecutive weeks (starting from current) with at least one activity logged
  int get streakWeeks {
    int streak = 0;
    for (int week = 0; week < 12; week++) {
      final minDay = week * 7;
      final maxDay = minDay + 6;
      final hasActivity = moments.any((m) => m.daysAgo >= minDay && m.daysAgo <= maxDay);
      if (hasActivity) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
