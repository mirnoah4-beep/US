import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/strings.dart';
import '../models/couple_preferences.dart';
import '../models/language_provider.dart';
import '../services/avatar_service.dart';

const _kBg = Color(0xFFF2E7DA);
const _kCard = Color(0xFFFBF5EC);
const _kAccent = Color(0xFF8B2E42);
const _kSelBorder = Color(0xFF8B2E42);
const _kSelSub = Color(0xFFE9CDD3);
const _kTitle = Color(0xFF3A2A28);
const _kSubtitle = Color(0xFF9A8A82);
const _kBorder = Color(0xFFD8CABF);

/// One user's onboarding answers. Written to settings/prefs_{uid} — never
/// merged destructively with the partner's (see couple_preferences.dart).
class OnboardingPreferences {
  final bool isParent;
  final List<String> locations;   // subset of kLocationIds, at least one
  final String pace;              // calm | mixed | active
  final String time;              // fewHours | evening | fullDay
  /// kidsHome | kidFree — only asked when [isParent].
  final String? childcareState;
  /// Only meaningful when kids are home.
  final TimeOfDay bedtime;

  const OnboardingPreferences({
    required this.isParent,
    required this.locations,
    required this.pace,
    required this.time,
    required this.childcareState,
    required this.bedtime,
  });

  UserPrefs toUserPrefs() {
    final kidsHome = isParent && childcareState == 'kidsHome';
    final bt = hhmmFromParts(bedtime.hour, bedtime.minute);
    return UserPrefs(
      locationPreferences: locations,
      pace: pace,
      availableTime: time,
      isParent: isParent,
      childcareState: isParent ? childcareState : null,
      bedtimeWeekday: kidsHome ? bt : null,
      bedtimeWeekend: kidsHome ? bt : null,
    );
  }
}

class OnboardingPreferencesScreen extends StatefulWidget {
  /// Needed for the optional profile-photo step (upload goes to
  /// users/{uid}/avatar.jpg). The user is always authenticated here.
  final String uid;
  final void Function(OnboardingPreferences prefs) onFinish;
  final VoidCallback? onCancel;

  const OnboardingPreferencesScreen({
    super.key,
    required this.uid,
    required this.onFinish,
    this.onCancel,
  });

  @override
  State<OnboardingPreferencesScreen> createState() =>
      _OnboardingPreferencesScreenState();
}

enum _Step { parents, place, pace, time, kids, photo }

class _OnboardingPreferencesScreenState
    extends State<OnboardingPreferencesScreen> {
  final _controller = PageController();
  int _page = 0;

  bool? _isParent;
  Set<String> _locations = {};
  String? _pace;
  String? _time;
  String? _childcare;
  // Kept even when the user toggles to kid-free, so toggling back restores it.
  TimeOfDay _bedtime = const TimeOfDay(hour: 20, minute: 30);
  String? _avatarUrl;
  bool _uploadingPhoto = false;

  /// The kids step exists only for parents; the photo step is always last.
  List<_Step> get _steps => [
        _Step.parents,
        _Step.place,
        _Step.pace,
        _Step.time,
        if (_isParent == true) _Step.kids,
        _Step.photo,
      ];

  _Step get _current => _steps[_page.clamp(0, _steps.length - 1)];
  bool get _isLast => _page == _steps.length - 1;

  bool get _canAdvance {
    switch (_current) {
      case _Step.parents:
        return _isParent != null;
      case _Step.place:
        return _locations.isNotEmpty;
      case _Step.pace:
        return _pace != null;
      case _Step.time:
        return _time != null;
      case _Step.kids:
        return _childcare != null;
      case _Step.photo:
        return !_uploadingPhoto;
    }
  }

  void _next(AppStrings s) {
    if (!_canAdvance) return;
    if (!_isLast) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      setState(() => _page++);
    } else {
      widget.onFinish(OnboardingPreferences(
        isParent: _isParent!,
        locations: kLocationIds.where(_locations.contains).toList(),
        pace: _pace!,
        time: _time!,
        childcareState: _isParent == true ? _childcare : null,
        bedtime: _bedtime,
      ));
    }
  }

  void _toggleLocation(String id) => setState(() {
        _locations = {..._locations};
        if (!_locations.remove(id)) _locations.add(id);
      });

  /// Permission is requested by the OS only now — after the user tapped
  /// "take photo" / "choose from gallery". A failure never traps the user:
  /// they can retry, or finish without a photo.
  Future<void> _pickPhoto(ImageSource source, AppStrings s) async {
    setState(() => _uploadingPhoto = true);
    try {
      final url = await AvatarService.pickAndUpload(widget.uid, source);
      if (!mounted) return;
      if (url != null) setState(() => _avatarUrl = url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.onbPhotoFailed), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickBedtime(AppStrings s) async {
    TimeOfDay picked = _bedtime;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(s.onbBedtimeLabel,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kTitle)),
              const SizedBox(height: 4),
              Text(s.onbBedtimeSubtitle,
                  style: const TextStyle(fontSize: 13, color: _kSubtitle)),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(
                      hours: picked.hour, minutes: picked.minute),
                  onTimerDurationChanged: (d) {
                    picked = TimeOfDay(
                        hour: d.inHours, minute: d.inMinutes % 60);
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() => _bedtime = picked);
                    Navigator.pop(ctx);
                  },
                  child: Text(s.onbNext,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              page: _page,
              pageCount: _steps.length,
              isParent: _isParent,
              s: s,
              onCancel: widget.onCancel,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final step in _steps)
                    switch (step) {
                      _Step.parents => _StepParents(
                          selected: _isParent,
                          s: s,
                          onChanged: (v) => setState(() => _isParent = v),
                        ),
                      _Step.place => _StepPlace(
                          selected: _locations,
                          s: s,
                          onToggle: _toggleLocation,
                        ),
                      _Step.pace => _StepPace(
                          selected: _pace,
                          s: s,
                          onChanged: (v) => setState(() => _pace = v),
                        ),
                      _Step.time => _StepTime(
                          selected: _time,
                          isParent: _isParent ?? false,
                          s: s,
                          onChanged: (v) => setState(() => _time = v),
                        ),
                      _Step.kids => _StepKids(
                          selected: _childcare,
                          bedtime: _bedtime,
                          s: s,
                          onChanged: (v) => setState(() => _childcare = v),
                          onPickBedtime: () => _pickBedtime(s),
                        ),
                      _Step.photo => _StepPhoto(
                          avatarUrl: _avatarUrl,
                          uploading: _uploadingPhoto,
                          s: s,
                          onTake: () => _pickPhoto(ImageSource.camera, s),
                          onGallery: () => _pickPhoto(ImageSource.gallery, s),
                        ),
                    },
                ],
              ),
            ),
            _BottomButton(
              label: _isLast
                  ? (_current == _Step.photo && _avatarUrl == null ? s.onbPhotoSkip : s.onbFinish)
                  : s.onbNext,
              canAdvance: _canAdvance,
              onTap: () => _next(s),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final bool? isParent;
  final AppStrings s;
  final VoidCallback? onCancel;

  const _TopBar({
    required this.page,
    required this.pageCount,
    required this.isParent,
    required this.s,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: Text(s.onbCancel,
                      style: const TextStyle(color: _kSubtitle, fontSize: 15)),
                )
              else
                const SizedBox(width: 64),
              _ProgressDots(page: page, count: pageCount),
              if (isParent == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.onbParentModeBadge,
                      style: const TextStyle(
                          fontSize: 12,
                          color: _kAccent,
                          fontWeight: FontWeight.w600)),
                )
              else
                const SizedBox(width: 80),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int page;
  final int count;
  const _ProgressDots({required this.page, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _kAccent : _kBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final bool canAdvance;
  final VoidCallback onTap;

  const _BottomButton({
    required this.label,
    required this.canAdvance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: canAdvance ? _kAccent : _kBorder,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: canAdvance ? onTap : null,
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
      ),
    );
  }
}

class _PageStep extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _PageStep({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _kTitle,
                height: 1.25)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(fontSize: 14, color: _kSubtitle)),
        ],
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.emoji,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _kSelSub : _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _kSelBorder : _kBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected ? _kAccent : _kTitle)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 13, color: _kSubtitle)),
                  ],
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _kAccent : Colors.transparent,
                border: Border.all(
                  color: selected ? _kAccent : _kBorder,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepParents extends StatelessWidget {
  final bool? selected;
  final AppStrings s;
  final void Function(bool) onChanged;

  const _StepParents({
    required this.selected,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PageStep(
      title: s.onbAreYouParentsTitle,
      children: [
        _OptionCard(
          emoji: '👨‍👩‍👧',
          title: s.onbYesParentsTitle,
          subtitle: s.onbYesParentsSubtitle,
          selected: selected == true,
          onTap: () => onChanged(true),
        ),
        _OptionCard(
          emoji: '💑',
          title: s.onbNoParentsTitle,
          subtitle: s.onbNoParentsSubtitle,
          selected: selected == false,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _StepPlace extends StatelessWidget {
  final Set<String> selected;
  final AppStrings s;
  final void Function(String) onToggle;

  const _StepPlace({
    required this.selected,
    required this.s,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Multi-select: every card toggles independently; at least one required
    // (enforced by _canAdvance). Same rose/check styling as single-select.
    return _PageStep(
      title: s.onbWhereDoYouLikeTitle,
      subtitle: s.onbWhereDoYouLikeSubtitle,
      children: [
        _OptionCard(
          emoji: '🌲',
          title: s.onbPlaceNatureTitle,
          selected: selected.contains('nature'),
          onTap: () => onToggle('nature'),
        ),
        _OptionCard(
          emoji: '☕',
          title: s.onbPlaceCafeTitle,
          selected: selected.contains('cafe'),
          onTap: () => onToggle('cafe'),
        ),
        _OptionCard(
          emoji: '🏠',
          title: s.onbPlaceHomeTitle,
          selected: selected.contains('home'),
          onTap: () => onToggle('home'),
        ),
        _OptionCard(
          emoji: '🎟️',
          title: s.onbPlaceOutTitle,
          selected: selected.contains('out'),
          onTap: () => onToggle('out'),
        ),
      ],
    );
  }
}

class _StepPace extends StatelessWidget {
  final String? selected;
  final AppStrings s;
  final void Function(String) onChanged;

  const _StepPace({
    required this.selected,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PageStep(
      title: s.onbWhatPaceTitle,
      children: [
        _OptionCard(
          emoji: '🕯️',
          title: s.onbPaceCalmTitle,
          selected: selected == 'calm',
          onTap: () => onChanged('calm'),
        ),
        _OptionCard(
          emoji: '⚖️',
          title: s.onbPaceMixedTitle,
          selected: selected == 'mixed',
          onTap: () => onChanged('mixed'),
        ),
        _OptionCard(
          emoji: '🏃',
          title: s.onbPaceActiveTitle,
          selected: selected == 'active',
          onTap: () => onChanged('active'),
        ),
      ],
    );
  }
}

class _StepTime extends StatelessWidget {
  final String? selected;
  final bool isParent;
  final AppStrings s;
  final void Function(String) onChanged;

  const _StepTime({
    required this.selected,
    required this.isParent,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final shortSub = isParent ? s.onbTimeShortParentSubtitle : s.onbTimeShortSubtitle;
    final eveningSub = isParent ? s.onbTimeEveningParentSubtitle : s.onbTimeEveningSubtitle;
    final daySub = isParent ? s.onbTimeDayParentSubtitle : s.onbTimeDaySubtitle;

    return _PageStep(
      title: s.onbHowMuchTimeTitle,
      children: [
        _OptionCard(
          emoji: '⏱️',
          title: s.timeFewHours,
          subtitle: shortSub,
          selected: selected == 'fewHours',
          onTap: () => onChanged('fewHours'),
        ),
        _OptionCard(
          emoji: '🌙',
          title: s.timeEvening,
          subtitle: eveningSub,
          selected: selected == 'evening',
          onTap: () => onChanged('evening'),
        ),
        _OptionCard(
          emoji: '☀️',
          title: s.timeFullDay,
          subtitle: daySub,
          selected: selected == 'fullDay',
          onTap: () => onChanged('fullDay'),
        ),
      ],
    );
  }
}

/// Parents only: the USUAL childcare situation (a default, not truth — the
/// "For tonight" sheet overrides it per request). Bedtime is shown only when
/// kids are home; the value is kept while hidden so toggling back restores it.
class _StepKids extends StatelessWidget {
  final String? selected;
  final TimeOfDay bedtime;
  final AppStrings s;
  final void Function(String) onChanged;
  final VoidCallback onPickBedtime;

  const _StepKids({
    required this.selected,
    required this.bedtime,
    required this.s,
    required this.onChanged,
    required this.onPickBedtime,
  });

  @override
  Widget build(BuildContext context) {
    return _PageStep(
      title: s.onbKidsTitle,
      subtitle: s.onbKidsSubtitle,
      children: [
        _OptionCard(
          emoji: '🏡',
          title: s.kidsHome,
          subtitle: s.onbKidsHomeSubtitle,
          selected: selected == 'kidsHome',
          onTap: () => onChanged('kidsHome'),
        ),
        _OptionCard(
          emoji: '🧸',
          title: s.kidFree,
          subtitle: s.onbKidFreeSubtitle,
          selected: selected == 'kidFree',
          onTap: () => onChanged('kidFree'),
        ),
        if (selected == 'kidsHome') ...[
          const SizedBox(height: 8),
          _BedtimePicker(bedtime: bedtime, s: s, onTap: onPickBedtime),
        ],
      ],
    );
  }
}

/// Optional profile photo — reuses the Settings avatar pipeline
/// (AvatarService). Skippable; an upload failure never blocks finishing.
class _StepPhoto extends StatelessWidget {
  final String? avatarUrl;
  final bool uploading;
  final AppStrings s;
  final VoidCallback onTake;
  final VoidCallback onGallery;

  const _StepPhoto({
    required this.avatarUrl,
    required this.uploading,
    required this.s,
    required this.onTake,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return _PageStep(
      title: s.onbPhotoTitle,
      subtitle: s.onbPhotoSubtitle,
      children: [
        Center(
          child: Container(
            width: 132,
            height: 132,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCard,
              border: Border.all(color: avatarUrl != null ? _kSelBorder : _kBorder, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: uploading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent))
                : avatarUrl != null
                    ? CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.person_outline, size: 56, color: _kSubtitle),
          ),
        ),
        _OptionCard(
          emoji: '📷',
          title: avatarUrl == null ? s.onbPhotoTake : s.onbPhotoRetake,
          selected: false,
          onTap: uploading ? () {} : onTake,
        ),
        _OptionCard(
          emoji: '🖼️',
          title: avatarUrl == null ? s.onbPhotoGallery : s.onbPhotoChange,
          selected: false,
          onTap: uploading ? () {} : onGallery,
        ),
        if (avatarUrl == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.onbPhotoSkipHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _kSubtitle)),
          ),
      ],
    );
  }
}

class _BedtimePicker extends StatelessWidget {
  final TimeOfDay bedtime;
  final AppStrings s;
  final VoidCallback onTap;

  const _BedtimePicker({
    required this.bedtime,
    required this.s,
    required this.onTap,
  });

  String _format(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            const Text('🌙', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.onbBedtimeLabel,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _kTitle)),
                  const SizedBox(height: 2),
                  Text(s.onbBedtimeSubtitle,
                      style: const TextStyle(
                          fontSize: 13, color: _kSubtitle)),
                ],
              ),
            ),
            Text(_format(bedtime),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kAccent)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: _kSubtitle, size: 20),
          ],
        ),
      ),
    );
  }
}
