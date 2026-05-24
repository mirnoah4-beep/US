import 'package:flutter/material.dart';

enum MomentStatus { good, needsAttention, reconnectSoon }

class MomentItem {
  final String id;
  final String title;
  final IconData icon;
  int daysAgo;
  final bool parentModeOnly;

  MomentItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.daysAgo,
    this.parentModeOnly = false,
  });

  MomentStatus get status {
    if (daysAgo <= 7) return MomentStatus.good;
    if (daysAgo <= 14) return MomentStatus.needsAttention;
    return MomentStatus.reconnectSoon;
  }

  String get statusLabel {
    switch (status) {
      case MomentStatus.good:
        return 'All good';
      case MomentStatus.needsAttention:
        return 'Soon';
      case MomentStatus.reconnectSoon:
        return 'Reconnect';
    }
  }

  Color get statusColor {
    switch (status) {
      case MomentStatus.good:
        return const Color(0xFF7BAE8A);
      case MomentStatus.needsAttention:
        return const Color(0xFFD4935A);
      case MomentStatus.reconnectSoon:
        return const Color(0xFFB85C5C);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case MomentStatus.good:
        return const Color(0xFFD4EAD9);
      case MomentStatus.needsAttention:
        return const Color(0xFFF5E4D0);
      case MomentStatus.reconnectSoon:
        return const Color(0xFFE8CECE);
    }
  }

  String get daysAgoLabel {
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    return '$daysAgo days ago';
  }

  MomentItem copyWith({int? daysAgo}) {
    return MomentItem(
      id: id,
      title: title,
      icon: icon,
      daysAgo: daysAgo ?? this.daysAgo,
      parentModeOnly: parentModeOnly,
    );
  }
}

List<MomentItem> buildInitialMoments() {
  return [
    MomentItem(id: 'date_night', title: 'Date night', icon: Icons.favorite_rounded, daysAgo: 11),
    MomentItem(id: 'home_date', title: 'Home date', icon: Icons.home_rounded, daysAgo: 5),
    MomentItem(id: 'went_out', title: 'Went out together', icon: Icons.directions_walk_rounded, daysAgo: 24),
    MomentItem(id: 'game', title: 'Played a game together', icon: Icons.sports_esports_rounded, daysAgo: 18),
    MomentItem(id: 'phone_free', title: 'Phone-free talk', icon: Icons.chat_bubble_outline_rounded, daysAgo: 9),
    MomentItem(id: 'walk', title: 'Took a walk', icon: Icons.nature_rounded, daysAgo: 6),
    MomentItem(id: 'no_kids', title: 'Time without kids', icon: Icons.child_friendly_rounded, daysAgo: 31, parentModeOnly: true),
  ];
}
