import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/moment_tile.dart';
import '../widgets/log_moment_sheet.dart';

class LastTimeScreen extends StatelessWidget {
  const LastTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final moments = state.visibleMoments;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 24),
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildLegend(),
            const SizedBox(height: 16),
            ...moments.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MomentTile(
                    item: item,
                    onTap: () => _openDetailSheet(context, item.id, state),
                  ),
                )),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLogSheet(context, state),
        backgroundColor: AppTheme.accentRose,
        foregroundColor: AppTheme.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log moment', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Last time',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'When did you last do this together?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
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
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: item.statusBgColor, borderRadius: BorderRadius.circular(16)),
                  child: Icon(item.icon, color: item.statusColor, size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(item.daysAgoLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  state.logMoment(momentId);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Nice. Small moments keep love strong.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
