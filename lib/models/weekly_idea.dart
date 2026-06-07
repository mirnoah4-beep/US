import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WeeklyIdea {
  final String titleNo;
  final String titleEn;
  final String categoryNo;
  final String categoryEn;
  final String metaNo;
  final String metaEn;
  final Color cardColor;
  final Color tagColor;
  final Color tagTextColor;
  final IconData icon;
  final String descriptionNo;
  final String descriptionEn;
  final String subtitleNo;
  final String subtitleEn;
  final Color buttonColor;

  const WeeklyIdea({
    required this.titleNo,
    required this.titleEn,
    required this.categoryNo,
    required this.categoryEn,
    required this.metaNo,
    required this.metaEn,
    required this.cardColor,
    required this.tagColor,
    required this.tagTextColor,
    required this.icon,
    required this.descriptionNo,
    required this.descriptionEn,
    this.subtitleNo = '',
    this.subtitleEn = '',
    this.buttonColor = const Color(0xFFC1544A),
  });

  String title(bool isNorwegian) => isNorwegian
      ? (titleNo.isNotEmpty ? titleNo : titleEn)
      : (titleEn.isNotEmpty ? titleEn : titleNo);

  String category(bool isNorwegian) => isNorwegian
      ? (categoryNo.isNotEmpty ? categoryNo : categoryEn)
      : (categoryEn.isNotEmpty ? categoryEn : categoryNo);

  String meta(bool isNorwegian) => isNorwegian
      ? (metaNo.isNotEmpty ? metaNo : metaEn)
      : (metaEn.isNotEmpty ? metaEn : metaNo);

  String description(bool isNorwegian) => isNorwegian
      ? (descriptionNo.isNotEmpty ? descriptionNo : descriptionEn)
      : (descriptionEn.isNotEmpty ? descriptionEn : descriptionNo);

  String subtitle(bool isNorwegian) => isNorwegian ? subtitleNo : subtitleEn;

  factory WeeklyIdea.fromJson(Map<String, dynamic> json) {
    String tryStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    final titleFallback = tryStr([
      'title', 'name', 'nameNo', 'nameEn', 'text', 'ideaTitle', 'idea', 'header', 'heading',
    ]);
    final tNo = tryStr(['titleNo']);
    final tEn = tryStr(['titleEn']);

    return WeeklyIdea(
      titleNo: tNo.isNotEmpty ? tNo : titleFallback,
      titleEn: tEn.isNotEmpty ? tEn : titleFallback,
      categoryNo: tryStr(['categoryNo', 'category', 'type', 'tag', 'label']),
      categoryEn: tryStr(['categoryEn', 'category', 'type', 'tag', 'label']),
      metaNo: tryStr(['metaNo', 'durationNo', 'meta', 'duration', 'time', 'timeEst', 'timeEstimate', 'length']),
      metaEn: tryStr(['metaEn', 'durationEn', 'meta', 'duration', 'time', 'timeEst', 'timeEstimate', 'length']),
      cardColor: _hexColor(json['cardColor'] as String? ?? '#FAECE7'),
      tagColor: _hexColor(json['tagColor'] as String? ?? '#F5C4B3'),
      tagTextColor: _hexColor(json['tagTextColor'] as String? ?? '#712B13'),
      icon: _iconFromName(json['iconName'] as String? ?? 'star_outline'),
      descriptionNo: tryStr(['descriptionNo', 'description', 'desc']),
      descriptionEn: tryStr(['descriptionEn', 'description', 'desc']),
      subtitleNo: tryStr(['subtitleNo']),
      subtitleEn: tryStr(['subtitleEn']),
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
