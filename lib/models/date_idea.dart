import 'package:flutter/material.dart';

enum IdeaCategory { tenMin, thirtyAtHome, oneHourOut, babysitterNight, parentMode }

class DateIdea {
  final String id;
  final String title;
  final String duration;
  final String categoryLabel;
  final IdeaCategory category;
  final IconData icon;
  bool isFavorite;
  final bool parentModeOnly;

  DateIdea({
    required this.id,
    required this.title,
    required this.duration,
    required this.categoryLabel,
    required this.category,
    required this.icon,
    this.isFavorite = false,
    this.parentModeOnly = false,
  });
}

List<DateIdea> buildInitialIdeas() {
  return [
    DateIdea(
      id: 'question_cards',
      title: 'Question cards on the couch',
      duration: '10 min',
      categoryLabel: '10 min',
      category: IdeaCategory.tenMin,
      icon: Icons.quiz_rounded,
    ),
    DateIdea(
      id: 'tea_dessert',
      title: 'Tea + dessert at home',
      duration: '20 min',
      categoryLabel: '30 min at home',
      category: IdeaCategory.thirtyAtHome,
      icon: Icons.local_cafe_rounded,
    ),
    DateIdea(
      id: 'evening_walk',
      title: 'Evening walk without phones',
      duration: '30–45 min',
      categoryLabel: '1 hour out',
      category: IdeaCategory.oneHourOut,
      icon: Icons.directions_walk_rounded,
    ),
    DateIdea(
      id: 'bowling_cafe',
      title: 'Bowling or café',
      duration: '1 hour',
      categoryLabel: '1 hour out',
      category: IdeaCategory.oneHourOut,
      icon: Icons.sports_rounded,
    ),
    DateIdea(
      id: 'cook_together',
      title: 'Cook together after bedtime',
      duration: '30 min',
      categoryLabel: '30 min at home',
      category: IdeaCategory.parentMode,
      icon: Icons.restaurant_rounded,
      parentModeOnly: true,
    ),
    DateIdea(
      id: 'babysitter_night',
      title: 'Plan babysitter night',
      duration: '1 hour+',
      categoryLabel: 'Babysitter night',
      category: IdeaCategory.babysitterNight,
      icon: Icons.nightlife_rounded,
      parentModeOnly: true,
    ),
  ];
}
