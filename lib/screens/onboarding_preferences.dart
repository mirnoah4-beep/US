import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/strings.dart';
import '../models/language_provider.dart';

const _kBg = Color(0xFFF2E7DA);
const _kCard = Color(0xFFFBF5EC);
const _kAccent = Color(0xFF8B2E42);
const _kSelBorder = Color(0xFF8B2E42);
const _kSelSub = Color(0xFFE9CDD3);
const _kTitle = Color(0xFF3A2A28);
const _kSubtitle = Color(0xFF9A8A82);
const _kBorder = Color(0xFFD8CABF);

class OnboardingPreferences {
  final bool isParent;
  final String place;
  final String pace;
  final String time;
  final TimeOfDay bedtime;

  const OnboardingPreferences({
    required this.isParent,
    required this.place,
    required this.pace,
    required this.time,
    required this.bedtime,
  });
}

class OnboardingPreferencesScreen extends StatefulWidget {
  final void Function(OnboardingPreferences prefs) onFinish;
  final VoidCallback? onCancel;

  const OnboardingPreferencesScreen({
    super.key,
    required this.onFinish,
    this.onCancel,
  });

  @override
  State<OnboardingPreferencesScreen> createState() =>
      _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState
    extends State<OnboardingPreferencesScreen> {
  final _controller = PageController();
  int _page = 0;

  bool? _isParent;
  String? _place;
  String? _pace;
  String? _time;
  TimeOfDay _bedtime = const TimeOfDay(hour: 20, minute: 30);

  bool get _canAdvance {
    switch (_page) {
      case 0:
        return _isParent != null;
      case 1:
        return _place != null;
      case 2:
        return _pace != null;
      case 3:
        return _time != null;
      default:
        return false;
    }
  }

  void _next(AppStrings s) {
    if (!_canAdvance) return;
    if (_page < 3) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      setState(() => _page++);
    } else {
      widget.onFinish(OnboardingPreferences(
        isParent: _isParent!,
        place: _place!,
        pace: _pace!,
        time: _time!,
        bedtime: _bedtime,
      ));
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
              isParent: _isParent,
              s: s,
              onCancel: widget.onCancel,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepParents(
                    selected: _isParent,
                    s: s,
                    onChanged: (v) => setState(() => _isParent = v),
                  ),
                  _StepPlace(
                    selected: _place,
                    s: s,
                    onChanged: (v) => setState(() => _place = v),
                  ),
                  _StepPace(
                    selected: _pace,
                    s: s,
                    onChanged: (v) => setState(() => _pace = v),
                  ),
                  _StepTime(
                    selected: _time,
                    isParent: _isParent ?? false,
                    bedtime: _bedtime,
                    s: s,
                    onChanged: (v) => setState(() => _time = v),
                    onPickBedtime: () => _pickBedtime(s),
                  ),
                ],
              ),
            ),
            _BottomButton(
              page: _page,
              canAdvance: _canAdvance,
              s: s,
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
  final bool? isParent;
  final AppStrings s;
  final VoidCallback? onCancel;

  const _TopBar({
    required this.page,
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
              _ProgressDots(page: page),
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
  const _ProgressDots({required this.page});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
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
  final int page;
  final bool canAdvance;
  final AppStrings s;
  final VoidCallback onTap;

  const _BottomButton({
    required this.page,
    required this.canAdvance,
    required this.s,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = page == 3 ? s.onbFinish : s.onbNext;
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
  final List<Widget> children;

  const _PageStep({required this.title, required this.children});

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
  final String? selected;
  final AppStrings s;
  final void Function(String) onChanged;

  const _StepPlace({
    required this.selected,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PageStep(
      title: s.onbWhereDoYouLikeTitle,
      children: [
        _OptionCard(
          emoji: '🌲',
          title: s.onbPlaceNatureTitle,
          selected: selected == 'nature',
          onTap: () => onChanged('nature'),
        ),
        _OptionCard(
          emoji: '☕',
          title: s.onbPlaceCafeTitle,
          selected: selected == 'cafe',
          onTap: () => onChanged('cafe'),
        ),
        _OptionCard(
          emoji: '🏠',
          title: s.onbPlaceHomeTitle,
          selected: selected == 'home',
          onTap: () => onChanged('home'),
        ),
        _OptionCard(
          emoji: '🗺️',
          title: s.onbPlaceOutTitle,
          selected: selected == 'out',
          onTap: () => onChanged('out'),
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
  final TimeOfDay bedtime;
  final AppStrings s;
  final void Function(String) onChanged;
  final VoidCallback onPickBedtime;

  const _StepTime({
    required this.selected,
    required this.isParent,
    required this.bedtime,
    required this.s,
    required this.onChanged,
    required this.onPickBedtime,
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
          title: s.onbTimeShortTitle,
          subtitle: shortSub,
          selected: selected == 'short',
          onTap: () => onChanged('short'),
        ),
        _OptionCard(
          emoji: '🌙',
          title: s.onbTimeEveningTitle,
          subtitle: eveningSub,
          selected: selected == 'evening',
          onTap: () => onChanged('evening'),
        ),
        _OptionCard(
          emoji: '☀️',
          title: s.onbTimeDayTitle,
          subtitle: daySub,
          selected: selected == 'day',
          onTap: () => onChanged('day'),
        ),
        if (isParent) ...[
          const SizedBox(height: 8),
          _BedtimePicker(
            bedtime: bedtime,
            s: s,
            onTap: onPickBedtime,
          ),
        ],
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
