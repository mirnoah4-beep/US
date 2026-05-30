import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WeeklyIdea {
  final String title;
  final String category;
  final String meta;
  final Color cardColor;
  final Color tagColor;
  final Color tagTextColor;
  final IconData icon;
  final String description;
  final Color buttonColor;

  const WeeklyIdea({
    required this.title,
    required this.category,
    required this.meta,
    required this.cardColor,
    required this.tagColor,
    required this.tagTextColor,
    required this.icon,
    required this.description,
    this.buttonColor = const Color(0xFFC1544A),
  });

  factory WeeklyIdea.fromJson(Map<String, dynamic> json) {
    String tryStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    String titleOrDiag() => tryStr([
      'titleNo', 'titleEn', 'title', 'name', 'nameNo', 'nameEn',
      'text', 'ideaTitle', 'idea', 'header', 'heading',
    ]);

    return WeeklyIdea(
      title: titleOrDiag(),
      category: tryStr([
        'category', 'categoryNo', 'categoryEn', 'type', 'tag', 'label',
      ]),
      meta: tryStr([
        'duration', 'durationNo', 'durationEn', 'meta', 'time',
        'timeEst', 'timeEstimate', 'length',
      ]),
      cardColor: _hexColor(json['cardColor'] as String? ?? '#FAECE7'),
      tagColor: _hexColor(json['tagColor'] as String? ?? '#F5C4B3'),
      tagTextColor: _hexColor(json['tagTextColor'] as String? ?? '#712B13'),
      icon: _iconFromName(json['iconName'] as String? ?? 'star_outline'),
      description: tryStr(['description', 'descriptionNo', 'descriptionEn', 'desc']),
      buttonColor: _hexColor(json['buttonColor'] as String? ?? '#C1544A'),
    );
  }

  static Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  static IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'coffee_outlined': Icons.coffee_outlined,
      'directions_walk_outlined': Icons.directions_walk_outlined,
      'tv_outlined': Icons.tv_outlined,
      'style_outlined': Icons.style_outlined,
      'local_cafe_outlined': Icons.local_cafe_outlined,
      'restaurant_outlined': Icons.restaurant_outlined,
      'park_outlined': Icons.park_outlined,
      'sports_esports_outlined': Icons.sports_esports_outlined,
      'music_note_outlined': Icons.music_note_outlined,
      'kitchen_outlined': Icons.kitchen_outlined,
      'beach_access_outlined': Icons.beach_access_outlined,
      'hiking_outlined': Icons.hiking_outlined,
      'casino_outlined': Icons.casino_outlined,
      'theater_comedy_outlined': Icons.theater_comedy_outlined,
      'palette_outlined': Icons.palette_outlined,
    };
    return map[name] ?? Icons.star_outline_rounded;
  }
}

class WeeklyIdeasDoc {
  final DateTime generatedAt;
  final int weekNumber;
  final String generatedBy;
  final List<WeeklyIdea> ideas;

  const WeeklyIdeasDoc({
    required this.generatedAt,
    required this.weekNumber,
    required this.generatedBy,
    required this.ideas,
  });

  bool get isAiGenerated => generatedBy == 'ai';

  bool get isStale =>
      DateTime.now().difference(generatedAt).inDays >= 7;

  factory WeeklyIdeasDoc.fromFirestore(Map<String, dynamic> data) {
    final ts = data['generatedAt'];
    final DateTime generatedAt;
    if (ts is Timestamp) {
      generatedAt = ts.toDate();
    } else if (ts is DateTime) {
      generatedAt = ts;
    } else {
      generatedAt = DateTime.now().subtract(const Duration(days: 8));
    }

    final ideasRaw = data['ideas'] as List<dynamic>? ?? [];
    final ideas = ideasRaw
        .map((e) => WeeklyIdea.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return WeeklyIdeasDoc(
      generatedAt: generatedAt,
      weekNumber: data['weekNumber'] as int? ?? 0,
      generatedBy: data['generatedBy'] as String? ?? 'curated',
      ideas: ideas,
    );
  }
}
