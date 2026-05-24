import 'package:flutter/foundation.dart';
import 'moment_item.dart';
import 'date_idea.dart';

class AppState extends ChangeNotifier {
  bool hasChildren = false;
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
    int score = 68;
    final dateNight = moments.firstWhere((m) => m.id == 'date_night');
    if (dateNight.daysAgo <= 7) score += 10;
    if (dateNight.daysAgo == 0) score += 5;
    return score.clamp(0, 100);
  }

  String get batteryMessage {
    final pct = batteryPercent;
    if (pct >= 85) return 'Your connection is strong. Keep it up.';
    if (pct >= 65) return 'You may need a little more quality time soon.';
    return 'It\'s been a while. Time to reconnect.';
  }

  MomentItem get lastDateMoment =>
      moments.firstWhere((m) => m.id == 'date_night');
}
