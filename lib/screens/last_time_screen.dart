import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/log_moment_sheet.dart';
import '../widgets/moment_tile.dart';

class LastTimeScreen extends StatelessWidget {
  const LastTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final moments = state.visibleMoments;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildLegend(),
            const SizedBox(height: 18),
            _buildCompactStats(),
            const SizedBox(height: 18),
            ...moments.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MomentTile(
                  item: item,
                  onTap: () => _openDetailSheet(context, item.id, state),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLogButton(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last time',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'When did you last do this together?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 17,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendChip(AppTheme.accentGreen, AppTheme.accentGreenLight, '0–7 days'),
        const SizedBox(width: 8),
        _legendChip(AppTheme.warningAmber, AppTheme.warningAmberLight, '8–14 days'),
        const SizedBox(width: 8),
        _legendChip(AppTheme.accentRose, AppTheme.accentRoseLight, '15+ days'),
      ],
    );
  }

  Widget _legendChip(Color color, Color bg, String label) {
    return Expanded(
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStats() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBeige,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentRoseLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppTheme.accentRose,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '6 moments this month  ·  3 weeks with quality time',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogButton(BuildContext context, AppState state) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: () => _openLogSheet(context, state),
        icon: const Icon(Icons.add_rounded, size: 28),
        label: const Text(
          'Log moment',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentRose,
          foregroundColor: AppTheme.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }

  void _openLogSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogMomentSheet(
        hasChildren: state.hasChildren,
        onLog: (id) => state.logMoment(id),
      ),
    );
  }

  void _openDetailSheet(BuildContext context, String momentId, AppState state) {
    final item = state.moments.firstWhere((m) => m.id == momentId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.statusBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.statusColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.daysAgoLabel,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  state.logMoment(momentId);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Nice. Small moments keep love strong.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: const Text('Log as today'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
