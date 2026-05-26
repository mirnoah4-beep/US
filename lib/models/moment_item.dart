import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum MomentStatus { good, needsAttention, reconnectSoon }

class IdeaSuggestion {
  final String text;
  final String duration;
  const IdeaSuggestion({required this.text, required this.duration});
}

class MomentItem {
  final String id;
  final String title;
  final IconData icon;
  int daysAgo;
  final bool parentModeOnly;
  final IdeaSuggestion? ideaSuggestion;

  MomentItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.daysAgo,
    this.parentModeOnly = false,
    this.ideaSuggestion,
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

  // Legacy colors used by MomentTile (list view)
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

  // Heat grid colors (spec-exact)
  Color get heatBgColor {
    switch (status) {
      case MomentStatus.good:
        return AppTheme.heatGreenBg;
      case MomentStatus.needsAttention:
        return AppTheme.heatAmberBg;
      case MomentStatus.reconnectSoon:
        return AppTheme.heatRedBg;
    }
  }

  Color get heatBorderColor {
    switch (status) {
      case MomentStatus.good:
        return AppTheme.heatGreenBorder;
      case MomentStatus.needsAttention:
        return AppTheme.heatAmberBorder;
      case MomentStatus.reconnectSoon:
        return AppTheme.heatRedBorder;
    }
  }

  Color get heatTextColor {
    switch (status) {
      case MomentStatus.good:
        return AppTheme.heatGreenText;
      case MomentStatus.needsAttention:
        return AppTheme.heatAmberText;
      case MomentStatus.reconnectSoon:
        return AppTheme.heatRedText;
    }
  }

  Color get heatIconColor {
    switch (status) {
      case MomentStatus.good: return const Color(0xFF3B6D11);
      case MomentStatus.needsAttention: return const Color(0xFF854F0B);
      case MomentStatus.reconnectSoon: return const Color(0xFF993C1D);
    }
  }

  String get daysAgoLabel {
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    return '$daysAgo days ago';
  }

  // For the status badge in ActivitySheet
  bool get isAllGood => status == MomentStatus.good;

  MomentItem copyWith({int? daysAgo}) {
    return MomentItem(
      id: id,
      title: title,
      icon: icon,
      daysAgo: daysAgo ?? this.daysAgo,
      parentModeOnly: parentModeOnly,
      ideaSuggestion: ideaSuggestion,
    );
  }
}

List<MomentItem> buildInitialMoments() {
  return [
    MomentItem(
      id: 'date_night',
      title: 'Date night',
      icon: Icons.favorite_border,
      daysAgo: 11,
      ideaSuggestion: const IdeaSuggestion(
        text: 'Try a new restaurant — let each other order for the other.',
        duration: '2–3 hours',
      ),
    ),
    MomentItem(
      id: 'home_date',
      title: 'Home date',
      icon: Icons.home_outlined,
      daysAgo: 5,
      ideaSuggestion: const IdeaSuggestion(
        text: 'Pick a film from the other\'s list. No phones after it starts.',
        duration: '1–2 hours',
      ),
    ),
    MomentItem(
      id: 'went_out',
      title: 'Went out together',
      icon: Icons.directions_walk,
      daysAgo: 18,
      ideaSuggestion: const IdeaSuggestion(
        text: 'Walk to a new neighbourhood and find a coffee spot you\'ve never tried.',
        duration: '1–2 hours',
      ),
    ),
    MomentItem(
      id: 'game',
      title: 'Game night',
      icon: Icons.sports_esports_outlined,
      daysAgo: 24,
      ideaSuggestion: const IdeaSuggestion(
        text: 'Dig out a board game or teach each other a card game you love.',
        duration: '45–90 min',
      ),
    ),
    MomentItem(
      id: 'walk',
      title: 'Took a walk',
      icon: Icons.directions_walk,
      daysAgo: 9,
      ideaSuggestion: const IdeaSuggestion(
        text: 'An evening loop around the block — phones in pockets, just talking.',
        duration: '20–30 min',
      ),
    ),
    MomentItem(
      id: 'no_kids',
      title: 'Time without kids',
      icon: Icons.child_care_outlined,
      daysAgo: 31,
      parentModeOnly: true,
      ideaSuggestion: const IdeaSuggestion(
        text: 'Ask a family member to take the kids for a few hours this weekend.',
        duration: '2–4 hours',
      ),
    ),
    MomentItem(
      id: 'phone_free',
      title: 'Phone-free talk',
      icon: Icons.chat_bubble_outline_rounded,
      daysAgo: 6,
      ideaSuggestion: const IdeaSuggestion(
        text: 'Sit down with tea tonight — phones in another room — and just catch up.',
        duration: '30 min',
      ),
    ),
  ];
}
