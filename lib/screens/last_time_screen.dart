import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/moment_item.dart';
import '../theme/app_theme.dart';
import '../widgets/log_moment_sheet.dart';

class LastTimeScreen extends StatelessWidget {
  const LastTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.watch<LanguageProvider>().s;

    final moments = [...state.visibleMoments]
      ..sort((a, b) => a.daysAgo.compareTo(b.daysAgo));

    final streak = state.streakWeeks;
    final record = state.streakRecord;
    final progress = record > 0
        ? (streak / record).clamp(0.0, 1.0)
        : (streak > 0 ? 1.0 : 0.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(s),
              const SizedBox(height: 20),
              Center(child: _buildFlameRing(s, streak, record, progress)),
              const SizedBox(height: 20),
              _buildWeeklyStrip(s, state.activeDaysThisWeek),
              const SizedBox(height: 16),
              _buildStatsRow(s, state),
              const SizedBox(height: 16),
              _buildActivityList(context, s, state, moments),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildButton(context, s, state),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.lastTimeTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.lastTimeSubtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── Flame ring ──────────────────────────────────────────────────────────────

  Widget _buildFlameRing(
      AppStrings s, int streak, int record, double progress) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(100, 100),
                painter: _RingPainter(progress: progress),
              ),
              const Icon(Icons.local_fire_department_rounded,
                  size: 36, color: Color(0xFFC04E28)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$streak',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD85A30),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              s.lastTimeStreakWeeks(streak),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD85A30),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          s.lastTimeInARow,
          style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
        ),
        if (record > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded,
                    size: 14, color: Color(0xFF854F0B)),
                const SizedBox(width: 5),
                Text(
                  s.lastTimeRecord(record),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF854F0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Weekly strip ─────────────────────────────────────────────────────────────

  Widget _buildWeeklyStrip(AppStrings s, Set<int> activeDays) {
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    final abbrevs = s.lastTimeDayAbbrevs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final weekday = i + 1;
          final isToday = weekday == today;
          final hasActivity = activeDays.contains(weekday);

          Color bgColor;
          Border? border;
          Widget? icon;

          if (hasActivity) {
            bgColor = const Color(0xFFD85A30);
            icon = const Icon(Icons.check_rounded,
                color: Colors.white, size: 14);
          } else if (isToday) {
            bgColor = Colors.transparent;
            border = Border.all(
                color: const Color(0xFFA32D2D), width: 2);
          } else {
            bgColor = const Color(0xFFF5E6DC);
          }

          return Column(
            children: [
              Text(
                abbrevs[i],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: border,
                ),
                child: icon != null ? Center(child: icon) : null,
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(AppStrings s, AppState state) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatItem(
              value: '${state.momentsTotal}', label: s.lastTimeTotalStat),
          _VertDivider(),
          _StatItem(
              value: '${state.momentsThisMonthCount}',
              label: s.lastTimeMonthStat),
          _VertDivider(),
          _StatItem(
              value: '${state.momentsThisWeekCount}',
              label: s.lastTimeWeekStat),
        ],
      ),
    );
  }

  // ── Activity list ────────────────────────────────────────────────────────────

  Widget _buildActivityList(BuildContext context, AppStrings s, AppState state,
      List<MomentItem> moments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppTheme.divider),
        for (int i = 0; i < moments.length; i++) ...[
          _ActivityRow(
            moment: moments[i],
            s: s,
            onTap: () => _confirmAndLog(context, s, state, moments[i]),
          ),
          const Divider(height: 1, color: AppTheme.divider,
              indent: 20, endIndent: 20),
        ],
      ],
    );
  }

  // ── Bottom button ────────────────────────────────────────────────────────────

  Widget _buildButton(
      BuildContext context, AppStrings s, AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _openLogSheet(context, state),
          icon: const Icon(Icons.add),
          label: Text(s.lastTimeLogButton),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA32D2D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndLog(BuildContext context, AppStrings s,
      AppState state, MomentItem moment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.momentTitle(moment.id),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          s.lastTimeLogConfirm,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.lastTimeLogCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.lastTimeLogConfirmButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true) state.logMoment(moment.id);
  }

  void _openLogSheet(BuildContext context, AppState state,
      {String? preSelected}) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LogMomentSheet(
        preSelected: preSelected,
        onLog: (id) => state.logMoment(id),
      ),
    );
  }
}

// ── Ring painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 8.0;
    final radius = size.width / 2 - strokeWidth / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Background ring
    paint.color = const Color(0xFFF5E6DC);
    canvas.drawCircle(center, radius, paint);

    // Progress arc
    if (progress > 0) {
      paint
        ..color = const Color(0xFFD85A30)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Stat item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      color: AppTheme.divider,
    );
  }
}

// ── Activity row ─────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final MomentItem moment;
  final AppStrings s;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.moment,
    required this.s,
    required this.onTap,
  });

  static ({Color bg, Color icon}) _colors(String id) {
    const romantic = (bg: Color(0xFFFBEAF0), icon: Color(0xFF993556));
    const home = (bg: Color(0xFFFAECE7), icon: Color(0xFF993C1D));
    const outdoor = (bg: Color(0xFFEAF3DE), icon: Color(0xFF3B6D11));
    const games = (bg: Color(0xFFFAEEDA), icon: Color(0xFF854F0B));
    const communication = (bg: Color(0xFFEEEDFE), icon: Color(0xFF534AB7));
    return switch (id) {
      'date_night' || 'send_note' => romantic,
      'home_date' || 'no_kids' => home,
      'went_out' || 'walk' => outdoor,
      'game' => games,
      'phone_free' => communication,
      _ => home,
    };
  }

  String _timeLabel() {
    if (moment.daysAgo == 0) return s.lastTimeToday;
    if (moment.daysAgo == 1) return s.lastTimeYesterday;
    return s.lastTimeDaysAgoLabel(moment.daysAgo);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors(moment.id);
    final isRecent = moment.daysAgo <= 1;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.bg,
              ),
              child: Icon(moment.icon, size: 18, color: colors.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                s.momentTitle(moment.id),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              _timeLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isRecent ? FontWeight.w600 : FontWeight.w400,
                color: isRecent
                    ? const Color(0xFFA32D2D)
                    : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
