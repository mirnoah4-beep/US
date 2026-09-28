import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The date-idea library — ONE source of truth shared with the server:
/// `functions/src/ideasLibrary.json` is bundled as a Flutter asset and read
/// by the Ideas screen, and imported by Cloud Functions for the curated tier
/// and the parent-mode rules. Cover images live at ideas/{id}.coverImageUrl
/// (resolved by IdeaImageService), exactly like before.
class LibraryIdea {
  final String id;
  final String titleEn, titleNo;
  final String subtitleEn, subtitleNo;
  final String durationEn, durationNo;
  final String categoryEn, categoryNo;
  final String descEn, descNo;
  final IconData icon;
  /// Any of: '10min' | 'home' | 'out' | 'talk' | 'food'. An idea can carry
  /// several; 'all' is every idea.
  final List<String> filters;
  final int colorIndex;
  /// Realistic with children around / after bedtime / at home.
  final bool parentFriendly;
  /// Assumes full freedom (babysitter, evening out).
  final bool requiresKidFree;

  const LibraryIdea({
    required this.id,
    required this.titleEn, required this.titleNo,
    required this.subtitleEn, required this.subtitleNo,
    required this.durationEn, required this.durationNo,
    required this.categoryEn, required this.categoryNo,
    required this.descEn, required this.descNo,
    required this.icon,
    required this.filters,
    required this.colorIndex,
    required this.parentFriendly,
    required this.requiresKidFree,
  });

  String title(bool no) => no ? titleNo : titleEn;
  String subtitle(bool no) => no ? subtitleNo : subtitleEn;
  String duration(bool no) => no ? durationNo : durationEn;
  String category(bool no) => no ? categoryNo : categoryEn;
  String desc(bool no) => no ? descNo : descEn;

  static LibraryIdea fromJson(Map<String, dynamic> j) => LibraryIdea(
        id: j['id'] as String,
        titleEn: j['titleEn'] as String? ?? '',
        titleNo: j['titleNo'] as String? ?? '',
        subtitleEn: j['subtitleEn'] as String? ?? '',
        subtitleNo: j['subtitleNo'] as String? ?? '',
        durationEn: j['durationEn'] as String? ?? '',
        durationNo: j['durationNo'] as String? ?? '',
        categoryEn: j['categoryEn'] as String? ?? '',
        categoryNo: j['categoryNo'] as String? ?? '',
        descEn: j['descEn'] as String? ?? '',
        descNo: j['descNo'] as String? ?? '',
        icon: iconFor(j['icon'] as String? ?? ''),
        filters: List<String>.from(j['filters'] as List? ?? const []),
        colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
        parentFriendly: j['parentFriendly'] as bool? ?? false,
        requiresKidFree: j['requiresKidFree'] as bool? ?? false,
      );
}

/// Icon names used in the JSON → Material icons (outlined, like before).
const Map<String, IconData> kLibraryIcons = {
  'quiz': Icons.quiz_outlined,
  'walk': Icons.directions_walk_outlined,
  'restaurant': Icons.restaurant_outlined,
  'cafe': Icons.local_cafe_outlined,
  'map': Icons.map_outlined,
  'sports': Icons.sports_outlined,
  'coffee': Icons.coffee_outlined,
  'edit': Icons.edit_outlined,
  'store': Icons.store_outlined,
  'music': Icons.music_note_outlined,
  'casino': Icons.casino_outlined,
  'book': Icons.menu_book_outlined,
  'headphones': Icons.headphones_outlined,
  'tv': Icons.tv_outlined,
  'hiking': Icons.hiking_outlined,
  'egg': Icons.egg_outlined,
  'fitness': Icons.fitness_center_outlined,
  'pizza': Icons.local_pizza_outlined,
  'sushi': Icons.set_meal_outlined,
  'kitchen': Icons.kitchen_outlined,
  'park': Icons.park_outlined,
  'flight': Icons.flight_takeoff_outlined,
  'sunset': Icons.wb_twilight_outlined,
  'star': Icons.star_border_outlined,
  'bike': Icons.directions_bike_outlined,
  'camera': Icons.photo_camera_outlined,
  'home': Icons.home_outlined,
  'palette': Icons.palette_outlined,
  'style': Icons.style_outlined,
  'spa': Icons.spa_outlined,
  'favorite': Icons.favorite_border_outlined,
  'mail': Icons.mail_outline,
  'candle': Icons.local_fire_department_outlined,
  'extension': Icons.extension_outlined,
  'weekend': Icons.weekend_outlined,
  'car': Icons.directions_car_outlined,
  'pool': Icons.pool_outlined,
  'museum': Icons.museum_outlined,
  'bathtub': Icons.bathtub_outlined,
  'bakery': Icons.bakery_dining_outlined,
  'city': Icons.location_city_outlined,
  'list': Icons.checklist_outlined,
  'playlist': Icons.queue_music_outlined,
  'cake': Icons.cake_outlined,
  'mic': Icons.mic_none_outlined,
  'phone_off': Icons.phonelink_erase_outlined,
  'yoga': Icons.self_improvement_outlined,
  'grill': Icons.outdoor_grill_outlined,
  'wb_sunny': Icons.wb_sunny_outlined,
  'calendar': Icons.calendar_today_outlined,
  'photo': Icons.photo_library_outlined,
  'stroller': Icons.stroller_outlined,
  'icecream': Icons.icecream_outlined,
  'beach': Icons.beach_access_outlined,
};

IconData iconFor(String name) => kLibraryIcons[name] ?? Icons.favorite_border_outlined;

/// Parses the bundled JSON. Pure, so it is unit-testable with a string.
List<LibraryIdea> parseIdeaLibrary(String jsonText) =>
    (jsonDecode(jsonText) as List)
        .map((e) => LibraryIdea.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

class IdeaLibrary {
  static const assetPath = 'functions/src/ideasLibrary.json';
  static List<LibraryIdea>? _cache;

  static Future<List<LibraryIdea>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final text = await rootBundle.loadString(assetPath);
    return _cache = List.unmodifiable(parseIdeaLibrary(text));
  }
}

/// Parent-mode rule, shared with the server:
///   * parent mode ON + usual situation → only parent-friendly ideas;
///   * parent mode ON + kid-free session ("For tonight" babysitter) →
///     parent-friendly ideas stay, couple-only ideas are allowed too;
///   * parent mode OFF → everything.
bool ideaAllowed(LibraryIdea idea, {required bool parentMode, required bool kidFreeSession}) {
  if (!parentMode) return true;
  if (idea.parentFriendly) return true;
  return kidFreeSession && idea.requiresKidFree;
}

/// The list the Ideas screen renders for a filter chip.
List<LibraryIdea> filterLibrary(
  List<LibraryIdea> all,
  String filter, {
  required bool parentMode,
  required bool kidFreeSession,
}) =>
    all
        .where((i) => ideaAllowed(i, parentMode: parentMode, kidFreeSession: kidFreeSession))
        .where((i) => filter == 'all' || i.filters.contains(filter))
        .toList();
