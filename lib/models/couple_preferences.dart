// Per-user preferences + derived couple profile (pure Dart, no Firebase).
//
// Mirrors functions/src/preferences.ts. Raw answers live per user in
// couples/{coupleId}/settings/prefs_{uid}; the couple profile is DERIVED and
// never written back over anyone's answers. Readers tolerate missing fields,
// the legacy single-value shapes on settings/main, and both time
// vocabularies, so RC1 data and new data coexist.

const kLocationIds = ['nature', 'cafe', 'home', 'out'];
const kTimeIds = ['fewHours', 'evening', 'fullDay'];
const kChildcareIds = ['kidsHome', 'kidFree'];
const kPaceIds = ['calm', 'mixed', 'active'];

const _timeOrder = {'fewHours': 0, 'evening': 1, 'fullDay': 2};

String? normalizeTime(Object? raw) => switch (raw) {
      'fewHours' || 'short' || 'under30' || '30to60' || 'little' => 'fewHours',
      'evening' || '2plus' || 'halfday' => 'evening',
      'fullDay' || 'day' || 'fullday' => 'fullDay',
      _ => null,
    };

/// Accepts a list, a single legacy `place` string, or the lifestyle
/// `preference` vocabulary (home/out/both). Unknown ids are dropped; the
/// result keeps the canonical order.
List<String> normalizeLocations(Object? raw) {
  final items = raw is List ? raw : (raw is String ? [raw] : const []);
  final out = <String>{};
  for (final it in items) {
    if (it is! String) continue;
    if (kLocationIds.contains(it)) {
      out.add(it);
    } else if (it == 'both') {
      out.addAll(kLocationIds);
    } else if (it == 'city') {
      out.add('cafe');
    } else if (it == 'activities') {
      out.add('out');
    }
  }
  return kLocationIds.where(out.contains).toList();
}

final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
String? normalizeHHmm(Object? raw) => raw is String && _hhmm.hasMatch(raw) ? raw : null;

String? hhmmFromParts(Object? hour, Object? minute) {
  if (hour is! int || hour < 0 || hour > 23) return null;
  final m = (minute is int && minute >= 0 && minute <= 59) ? minute : 0;
  return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// One user's raw answers. Every field optional — a partial doc is valid.
class UserPrefs {
  final List<String> locationPreferences;
  final String? pace;
  final String? availableTime;
  final bool? isParent;
  final String? childcareState;
  final String? bedtimeWeekday;
  final String? bedtimeWeekend;

  const UserPrefs({
    this.locationPreferences = const [],
    this.pace,
    this.availableTime,
    this.isParent,
    this.childcareState,
    this.bedtimeWeekday,
    this.bedtimeWeekend,
  });

  bool get isEmpty =>
      locationPreferences.isEmpty && pace == null && availableTime == null &&
      isParent == null && childcareState == null && bedtimeWeekday == null && bedtimeWeekend == null;

  /// Parses a prefs_{uid} document. Never throws.
  static UserPrefs? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return UserPrefs(
      locationPreferences: normalizeLocations(raw['locationPreferences']),
      pace: kPaceIds.contains(raw['pace']) ? raw['pace'] as String : null,
      availableTime: normalizeTime(raw['availableTime']),
      isParent: raw['isParent'] is bool ? raw['isParent'] as bool : null,
      childcareState: kChildcareIds.contains(raw['childcareState']) ? raw['childcareState'] as String : null,
      bedtimeWeekday: normalizeHHmm(raw['bedtimeWeekday']),
      bedtimeWeekend: normalizeHHmm(raw['bedtimeWeekend']),
    );
  }

  /// The legacy couple-level settings/main document (onboarding fields AND
  /// lifestyle fields) read as one fallback answer set.
  static UserPrefs? fromLegacyMain(Map<String, dynamic>? main) {
    if (main == null) return null;
    final bw = normalizeHHmm(main['bedtimeWeekday']) ?? hhmmFromParts(main['bedtimeHour'], main['bedtimeMinute']);
    final p = UserPrefs(
      locationPreferences: normalizeLocations(main['place'] ?? main['preference']),
      pace: kPaceIds.contains(main['pace']) ? main['pace'] as String : null,
      availableTime: normalizeTime(main['availableTime']) ??
          normalizeTime(main['weekdayTime']) ??
          normalizeTime(main['weekendTime']),
      isParent: main['isParent'] is bool
          ? main['isParent'] as bool
          : (main['parentMode'] is bool ? main['parentMode'] as bool : null),
      bedtimeWeekday: bw,
      bedtimeWeekend: normalizeHHmm(main['bedtimeWeekend']) ?? bw,
    );
    return p.isEmpty ? null : p;
  }

  /// Exactly the keys the rules allow on prefs_{uid} (plus the timestamps
  /// the writer adds). Absent answers are omitted, never written as junk.
  Map<String, dynamic> toMap() => {
        if (locationPreferences.isNotEmpty) 'locationPreferences': locationPreferences,
        if (pace != null) 'pace': pace,
        if (availableTime != null) 'availableTime': availableTime,
        if (isParent != null) 'isParent': isParent,
        if (childcareState != null) 'childcareState': childcareState,
        if (bedtimeWeekday != null) 'bedtimeWeekday': bedtimeWeekday,
        if (bedtimeWeekend != null) 'bedtimeWeekend': bedtimeWeekend,
        'schemaVersion': 1,
      };
}

class RankedLocation {
  final String id;
  /// 2 = chosen by both partners, 1 = one-sided (still eligible).
  final int weight;
  const RankedLocation(this.id, this.weight);
}

class CoupleProfile {
  final List<RankedLocation> locations;
  final String availableTime;
  final bool isParent;
  final String childcareState;
  final String? bedtimeWeekday;
  final String? bedtimeWeekend;
  final String pace;
  /// 'prefs' | 'legacy' | 'defaults'
  final String source;

  const CoupleProfile({
    required this.locations,
    required this.availableTime,
    required this.isParent,
    required this.childcareState,
    required this.bedtimeWeekday,
    required this.bedtimeWeekend,
    required this.pace,
    required this.source,
  });

  List<String> get locationIds => locations.map((l) => l.id).toList();
}

String? _earliest(String? a, String? b) {
  if (a != null && b != null) return a.compareTo(b) <= 0 ? a : b;
  return a ?? b;
}

/// Same derivation as the server: union of locations (both-chosen ranked
/// first), the more constrained time, parent if either is, kidsHome as the
/// conservative childcare default, earliest bedtime. Inputs are untouched.
CoupleProfile deriveCoupleProfile(List<UserPrefs?> users, {UserPrefs? legacy}) {
  final answered = users.whereType<UserPrefs>().where((u) => !u.isEmpty).toList();
  final source = answered.isNotEmpty ? 'prefs' : (legacy != null ? 'legacy' : 'defaults');
  final inputs = answered.isNotEmpty ? answered : (legacy != null ? [legacy] : <UserPrefs>[]);

  final counts = <String, int>{};
  var voters = 0;
  for (final u in inputs) {
    if (u.locationPreferences.isEmpty) continue;
    voters++;
    for (final l in u.locationPreferences) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
  }
  final locations = counts.isEmpty
      ? kLocationIds.map((id) => RankedLocation(id, 1)).toList()
      : (kLocationIds
          .where(counts.containsKey)
          .map((l) => RankedLocation(l, voters > 1 && counts[l] == voters ? 2 : 1))
          .toList()
        ..sort((a, b) => b.weight.compareTo(a.weight)));

  final times = inputs.map((u) => u.availableTime).whereType<String>().toList();
  final availableTime = times.isEmpty
      ? 'evening'
      : times.reduce((a, b) => _timeOrder[a]! <= _timeOrder[b]! ? a : b);

  final isParent = inputs.any((u) => u.isParent == true);
  final care = inputs.map((u) => u.childcareState).whereType<String>().toList();
  final childcareState = !isParent
      ? 'kidFree'
      : (care.contains('kidsHome') || care.isEmpty ? 'kidsHome' : 'kidFree');

  String? bw;
  String? be;
  if (isParent) {
    for (final u in inputs) {
      bw = _earliest(bw, u.bedtimeWeekday);
      be = _earliest(be, u.bedtimeWeekend);
    }
  }
  final paces = inputs.map((u) => u.pace).whereType<String>().toList();
  final pace = paces.isEmpty ? 'mixed' : (paces.every((p) => p == paces.first) ? paces.first : 'mixed');

  return CoupleProfile(
    locations: locations,
    availableTime: availableTime,
    isParent: isParent,
    childcareState: childcareState,
    bedtimeWeekday: bw,
    bedtimeWeekend: be,
    pace: pace,
    source: source,
  );
}

/// The legacy summary a NEW client keeps writing to settings/main during the
/// compatibility window, so an RC1 client (and the old server fallback)
/// still see a sensible couple-level value. Booleans only ever move to
/// true (the other partner may have said yes); everything else mirrors the
/// derived profile of both partners' answers.
Map<String, dynamic> legacySummaryFor(CoupleProfile p, {Map<String, dynamic>? existingMain}) {
  final legacyPlace = p.locationIds.length == 1 ? p.locationIds.single : null;
  final ids = p.locationIds.toSet();
  final preference = ids.isEmpty || (ids.contains('home') && ids.length > 1)
      ? 'both'
      : (ids.contains('home') ? 'home' : 'out');
  final legacyTime = switch (p.availableTime) {
    'fewHours' => ('short', '30to60', 'little'),
    'fullDay' => ('day', '2plus', 'fullday'),
    _ => ('evening', '2plus', 'halfday'),
  };
  final wasParent = existingMain?['isParent'] == true || existingMain?['parentMode'] == true;
  final isParent = p.isParent || wasParent;
  final bt = p.bedtimeWeekday;
  return {
    'onboardingDone': true,
    'isParent': isParent,
    'parentMode': isParent,
    'place': ?legacyPlace,
    'preference': preference,
    'pace': p.pace,
    'availableTime': legacyTime.$1,
    'weekdayTime': legacyTime.$2,
    'weekendTime': legacyTime.$3,
    'bedtimeWeekday': ?bt,
    'bedtimeWeekend': ?p.bedtimeWeekend,
    if (bt != null) 'bedtimeHour': int.parse(bt.substring(0, 2)),
    if (bt != null) 'bedtimeMinute': int.parse(bt.substring(3, 5)),
  };
}
