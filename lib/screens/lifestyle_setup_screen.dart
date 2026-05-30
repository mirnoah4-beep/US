import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../l10n/strings.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';

class LifestyleSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const LifestyleSetupScreen({super.key, required this.isFirstTime});

  @override
  State<LifestyleSetupScreen> createState() => _LifestyleSetupScreenState();
}

class _LifestyleSetupScreenState extends State<LifestyleSetupScreen> {
  int _step = 0; // 0–3 = steps, 4 = done

  String _weekdayTime = '30to60';
  String _preference = 'both';
  bool _parentMode = false;
  TimeOfDay _bedtimeWeekday = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _bedtimeWeekend = const TimeOfDay(hour: 21, minute: 0);
  String _weekendTime = 'halfday';

  bool _saving = false;

  AppStrings get _s => context.read<LanguageProvider>().s;

  void _next() => setState(() => _step++);

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await _saveToPrefs();
    if (mounted) setState(() { _saving = false; _step = 4; });
  }

  Future<void> _saveAndFinish() async {
    setState(() => _saving = true);
    await _saveToPrefs();
    if (mounted) setState(() { _saving = false; _step = 4; });
  }

  Future<void> _saveToPrefs() async {
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weekdayTime', _weekdayTime);
    await prefs.setString('weekendTime', _weekendTime);
    await prefs.setString('preference', _preference);
    await prefs.setBool('parentMode', _parentMode);
    if (_parentMode) {
      await prefs.setString(
        'bedtimeWeekday',
        '${_bedtimeWeekday.hour.toString().padLeft(2, '0')}:${_bedtimeWeekday.minute.toString().padLeft(2, '0')}',
      );
      await prefs.setString(
        'bedtimeWeekend',
        '${_bedtimeWeekend.hour.toString().padLeft(2, '0')}:${_bedtimeWeekend.minute.toString().padLeft(2, '0')}',
      );
    }
    if (mounted) context.read<AppState>().setHasChildren(_parentMode);
  }

  Future<void> _pickTime(bool isWeekday) async {
    final initial = isWeekday ? _bedtimeWeekday : _bedtimeWeekend;
    TimeOfDay selected = initial;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      _s.lifestyleCancel,
                      style: const TextStyle(color: Color(0xFFB4B2A9)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Color(0xFFC1544A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                    2024, 1, 1, initial.hour, initial.minute),
                onDateTimeChanged: (dt) {
                  selected =
                      TimeOfDay(hour: dt.hour, minute: dt.minute);
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() {
        if (isWeekday) _bedtimeWeekday = selected;
        else _bedtimeWeekend = selected;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _step == 4 ? _buildDoneScreen() : _buildStepScreen(),
      ),
    );
  }

  Widget _buildStepScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        _buildProgressDots(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: _buildStepContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final showBack = !widget.isFirstTime || _step > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: _back,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 16, color: AppTheme.textSubtle),
                ),
              ),
            )
          else
            const SizedBox(width: 34),
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : _skip,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSubtle,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_s.lifestyleSkip, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final reached = i <= _step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: reached
                  ? const Color(0xFFC1544A)
                  : const Color(0xFFE0D9D0),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      default: return [];
    }
  }

  // ── Step 1 — Weekdays ──────────────────────────────────────────────────

  List<Widget> _buildStep1() {
    return [
      _stepQuestion(_s.lifestyleStep1Q),
      const SizedBox(height: 6),
      _stepSub(_s.lifestyleStep1Sub),
      const SizedBox(height: 24),
      _selectionCard(
        icon: Icons.bolt_outlined,
        title: _s.lifestyleUnder30,
        subtitle: _s.lifestyleUnder30Sub,
        value: 'under30',
        selected: _weekdayTime == 'under30',
        onTap: () => setState(() => _weekdayTime = 'under30'),
      ),
      const SizedBox(height: 10),
      _selectionCard(
        icon: Icons.access_time_outlined,
        title: _s.lifestyle30to60,
        subtitle: _s.lifestyle30to60Sub,
        value: '30to60',
        selected: _weekdayTime == '30to60',
        onTap: () => setState(() => _weekdayTime = '30to60'),
      ),
      const SizedBox(height: 10),
      _selectionCard(
        icon: Icons.wb_sunny_outlined,
        title: _s.lifestyle2plus,
        subtitle: _s.lifestyle2plusSub,
        value: '2plus',
        selected: _weekdayTime == '2plus',
        onTap: () => setState(() => _weekdayTime = '2plus'),
      ),
      const SizedBox(height: 28),
      _nextButton(),
    ];
  }

  // ── Step 2 — Preferences ────────────────────────────────────────────────

  List<Widget> _buildStep2() {
    return [
      _stepQuestion(_s.lifestyleStep2Q),
      const SizedBox(height: 6),
      _stepSub(_s.lifestyleStep2Sub),
      const SizedBox(height: 24),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _selectionCard(
                icon: Icons.home_outlined,
                title: _s.lifestyleHome,
                subtitle: _s.lifestyleHomeSub,
                value: 'home',
                selected: _preference == 'home',
                onTap: () => setState(() => _preference = 'home'),
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _selectionCard(
                icon: Icons.place_outlined,
                title: _s.lifestyleOut,
                subtitle: _s.lifestyleOutSub,
                value: 'out',
                selected: _preference == 'out',
                onTap: () => setState(() => _preference = 'out'),
                compact: true,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _selectionCard(
        icon: Icons.favorite_border,
        title: _s.lifestyleBoth,
        subtitle: _s.lifestyleBothSub,
        value: 'both',
        selected: _preference == 'both',
        onTap: () => setState(() => _preference = 'both'),
      ),
      const SizedBox(height: 28),
      _nextButton(),
    ];
  }

  // ── Step 3 — Parent mode ────────────────────────────────────────────────

  List<Widget> _buildStep3() {
    return [
      _stepQuestion(_s.lifestyleStep3Q),
      const SizedBox(height: 6),
      _stepSub(_s.lifestyleStep3Sub),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _parentMode
                ? const Color(0xFFC1544A)
                : const Color(0xFFE0D9D0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFAEEDA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.nightlight_outlined,
                  size: 22, color: Color(0xFF854F0B)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _s.lifestyleHaveKids,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2420),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _s.lifestyleHaveKidsSub,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
                  ),
                ],
              ),
            ),
            Switch(
              value: _parentMode,
              onChanged: (v) => setState(() => _parentMode = v),
              activeColor: const Color(0xFFC1544A),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE0D9D0),
              trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: _parentMode
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFAC775), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s.lifestyleBedtimeQ,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C2420),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _bedtimePicker(
                          _s.lifestyleWeekdays, _bedtimeWeekday,
                          () => _pickTime(true)),
                      const SizedBox(height: 8),
                      _bedtimePicker(
                          _s.lifestyleWeekends, _bedtimeWeekend,
                          () => _pickTime(false)),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      const SizedBox(height: 28),
      _nextButton(),
    ];
  }

  // ── Step 4 — Weekends ───────────────────────────────────────────────────

  List<Widget> _buildStep4() {
    return [
      _stepQuestion(_s.lifestyleStep4Q),
      const SizedBox(height: 6),
      _stepSub(_s.lifestyleStep4Sub),
      const SizedBox(height: 24),
      _selectionCard(
        icon: Icons.coffee_outlined,
        title: _s.lifestyleLittle,
        subtitle: _s.lifestyleLittleSub,
        value: 'little',
        selected: _weekendTime == 'little',
        onTap: () => setState(() => _weekendTime = 'little'),
      ),
      const SizedBox(height: 10),
      _selectionCard(
        icon: Icons.wb_sunny_outlined,
        title: _s.lifestyleHalfday,
        subtitle: _s.lifestyleHalfdaySub,
        value: 'halfday',
        selected: _weekendTime == 'halfday',
        onTap: () => setState(() => _weekendTime = 'halfday'),
      ),
      const SizedBox(height: 10),
      _selectionCard(
        icon: Icons.star_outline,
        title: _s.lifestyleFullday,
        subtitle: _s.lifestyleFulldaySub,
        value: 'fullday',
        selected: _weekendTime == 'fullday',
        onTap: () => setState(() => _weekendTime = 'fullday'),
      ),
      const SizedBox(height: 28),
      _saveButton(),
    ];
  }

  // ── Done screen ─────────────────────────────────────────────────────────

  Widget _buildDoneScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF3DE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 36, color: Color(0xFF3B6D11)),
            ),
            const SizedBox(height: 24),
            Text(
              _s.lifestyleDoneTitle,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2420),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _s.lifestyleDoneBody,
              style: const TextStyle(
                  fontSize: 15, color: AppTheme.textSubtle, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.popUntil(
                    context, (route) => route.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC1544A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _s.lifestyleBackToApp,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────

  Widget _selectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFAECE7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFC1544A)
                : const Color(0xFFE0D9D0),
            width: 1.5,
          ),
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFC1544A)
                                  .withValues(alpha: 0.12)
                              : const Color(0xFFF1EFE8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon,
                            size: 20,
                            color: selected
                                ? const Color(0xFFC1544A)
                                : AppTheme.textSubtle),
                      ),
                      const Spacer(),
                      _checkCircle(selected),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFFC1544A)
                          : const Color(0xFF2C2420),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSubtle)),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFC1544A)
                              .withValues(alpha: 0.12)
                          : const Color(0xFFF1EFE8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        size: 22,
                        color: selected
                            ? const Color(0xFFC1544A)
                            : AppTheme.textSubtle),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xFFC1544A)
                                : const Color(0xFF2C2420),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSubtle)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _checkCircle(selected),
                ],
              ),
      ),
    );
  }

  Widget _checkCircle(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFC1544A) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? const Color(0xFFC1544A)
              : const Color(0xFFD3D1C7),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _bedtimePicker(
      String label, TimeOfDay time, VoidCallback onTap) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C2420),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFAC775)),
            ),
            child: Text(
              formatted,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF854F0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _next,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFC1544A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(_s.lifestyleNext,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _saving ? null : _saveAndFinish,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFC1544A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(_s.lifestyleSave,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _stepQuestion(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2C2420),
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _stepSub(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 15, color: AppTheme.textSubtle, height: 1.4),
    );
  }
}
