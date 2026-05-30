import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/language_provider.dart';
import '../models/reminders_provider.dart';
import '../theme/app_theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  AppStrings get _s => context.read<LanguageProvider>().s;

  Future<void> _pickEveningTime() async {
    final r = context.read<RemindersProvider>();
    final picked = await showTimePicker(
      context: context,
      initialTime: r.eveningTime,
      builder: _themed,
    );
    if (picked != null && mounted) r.setEveningTime(picked);
  }

  Future<void> _pickWeeklyTime() async {
    final r = context.read<RemindersProvider>();
    final picked = await showTimePicker(
      context: context,
      initialTime: r.weeklyPlanTime,
      builder: _themed,
    );
    if (picked != null && mounted) r.setWeeklyPlanTime(picked);
  }

  Widget _themed(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC1544A),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF2C2420),
          ),
        ),
        child: child!,
      );

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final r = context.watch<RemindersProvider>();
    final s = _s;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(title: s.remindersTitle),
              const SizedBox(height: 6),
              Text(
                s.remindersSubtitle,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
              ),
              const SizedBox(height: 28),
              _SectionLabel(s.remindersEveningSectionLabel),
              const SizedBox(height: 8),
              _buildEveningCard(r, s),
              const SizedBox(height: 24),
              _SectionLabel(s.remindersWeeklySectionLabel),
              const SizedBox(height: 8),
              _buildWeeklyCard(r, s),
            ],
          ),
        ),
      ),
    );
  }

  // ── Evening card ──────────────────────────────────────────────────────────

  Widget _buildEveningCard(RemindersProvider r, AppStrings s) {
    return _Card(children: [
      _ToggleRow(
        icon: Icons.notifications_none,
        iconBg: const Color(0xFFFAECE7),
        iconColor: const Color(0xFFC1544A),
        title: s.remindersEveningTitle,
        subtitle: s.remindersEveningSub,
        value: r.eveningEnabled,
        onChanged: r.setEveningEnabled,
      ),
      const _Divider(),
      AnimatedOpacity(
        opacity: r.eveningEnabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !r.eveningEnabled,
          child: Column(children: [
            _TimeRow(
              icon: Icons.access_time_outlined,
              iconBg: const Color(0xFFF1EFE8),
              iconColor: const Color(0xFF5F5E5A),
              title: s.remindersTime,
              subtitle: s.remindersTapToChange,
              timeLabel: r.formattedEveningTime,
              onTap: _pickEveningTime,
            ),
            const _Divider(),
            _DayPickerRow(
              days: s.remindersDayAbbreviations,
              selected: r.eveningDays,
              onToggle: r.toggleEveningDay,
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Weekly planning card ──────────────────────────────────────────────────

  Widget _buildWeeklyCard(RemindersProvider r, AppStrings s) {
    final weeklySub = r.weeklyPlanEnabled
        ? s.remindersWeeklyTimeLabel(r.formattedWeeklyPlanTime)
        : s.remindersWeeklyOff;

    return _Card(children: [
      _ToggleRow(
        icon: Icons.calendar_today_outlined,
        iconBg: const Color(0xFFEAF3DE),
        iconColor: const Color(0xFF3B6D11),
        title: s.remindersWeeklyTitle,
        subtitle: weeklySub,
        value: r.weeklyPlanEnabled,
        onChanged: r.setWeeklyPlanEnabled,
      ),
      const _Divider(),
      AnimatedOpacity(
        opacity: r.weeklyPlanEnabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !r.weeklyPlanEnabled,
          child: _TimeRow(
            icon: Icons.access_time_outlined,
            iconBg: const Color(0xFFF1EFE8),
            iconColor: const Color(0xFF5F5E5A),
            title: s.remindersTime,
            subtitle: s.remindersWeeklyTimeSub,
            timeLabel: r.formattedWeeklyPlanTime,
            onTap: _pickWeeklyTime,
          ),
        ),
      ),
      const _Divider(),
      _ToggleRow(
        icon: Icons.favorite_border,
        iconBg: const Color(0xFFFAEEDA),
        iconColor: const Color(0xFF854F0B),
        title: s.remindersNewIdeas,
        subtitle: s.remindersNewIdeasSub,
        value: r.newIdeasEnabled,
        onChanged: r.setNewIdeasEnabled,
      ),
    ]);
  }

}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: AppTheme.textSubtle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2C2420),
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFFB4B2A9),
        letterSpacing: 0.77,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFF0ECE6),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF2C2420),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFC1544A),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFE0D9D0),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String timeLabel;
  final VoidCallback onTap;

  const _TimeRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF2C2420),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFAECE7),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          timeLabel,
          style: const TextStyle(
            color: Color(0xFFC1544A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DayPickerRow extends StatelessWidget {
  final List<String> days;
  final List<bool> selected;
  final ValueChanged<int> onToggle;

  const _DayPickerRow({
    required this.days,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final sel = selected[i];
          return GestureDetector(
            onTap: () => onToggle(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFC1544A) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel
                      ? const Color(0xFFC1544A)
                      : const Color(0xFFE0D9D0),
                ),
              ),
              child: Center(
                child: Text(
                  days[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppTheme.textSubtle,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
