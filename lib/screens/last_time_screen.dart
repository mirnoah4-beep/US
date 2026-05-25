import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/moment_item.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_sheet.dart';
import '../widgets/heat_card.dart';
import '../widgets/log_moment_sheet.dart';

class LastTimeScreen extends StatelessWidget {
  const LastTimeScreen({super.key});

  List<MomentItem> _sortedMoments(List<MomentItem> moments) {
    final items = [...moments];
    items.sort((a, b) {
      // positive first: green=0, amber=1, red=2
      int pa = switch (a.status) {
        MomentStatus.good => 0,
        MomentStatus.needsAttention => 1,
        MomentStatus.reconnectSoon => 2,
      };
      int pb = switch (b.status) {
        MomentStatus.good => 0,
        MomentStatus.needsAttention => 1,
        MomentStatus.reconnectSoon => 2,
      };
      if (pa != pb) return pa.compareTo(pb);
      return a.daysAgo.compareTo(b.daysAgo);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final moments = _sortedMoments(state.visibleMoments);

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: _LogFab(
        onTap: () => _openLogSheet(context, state),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildLegend(),
                  const SizedBox(height: 14),
                  _StatsBar(state: state),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 104,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = moments[index];
                    return HeatCard(
                      key: ValueKey(item.id),
                      item: item,
                      onTap: () => _openActivitySheet(context, item, state),
                    );
                  },
                  childCount: moments.length,
                ),
              ),
            ),
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
            fontFamily: 'Georgia',
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'When did you last do this together?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendChip(AppTheme.heatGreenText, AppTheme.heatGreenBg, AppTheme.heatGreenBorder, '0–7 days'),
        const SizedBox(width: 8),
        _legendChip(AppTheme.heatAmberText, AppTheme.heatAmberBg, AppTheme.heatAmberBorder, '8–14 days'),
        const SizedBox(width: 8),
        _legendChip(AppTheme.heatRedText, AppTheme.heatRedBg, AppTheme.heatRedBorder, '15+ days'),
      ],
    );
  }

  Widget _legendChip(Color text, Color bg, Color border, String label) {
    return Expanded(
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: text, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openActivitySheet(BuildContext context, MomentItem item, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivitySheet(
        item: item,
        onLog: () => state.logMoment(item.id),
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
}

class _StatsBar extends StatelessWidget {
  final AppState state;
  const _StatsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final count = state.momentCountThisMonth;
    final streak = state.streakWeeks;
    final streakText = streak == 1
        ? '1 week in a row'
        : '$streak weeks in a row';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBeige,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.bar_chart, color: AppTheme.textSecondary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count moment${count == 1 ? '' : 's'} this month  ·  $streakText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogFab extends StatelessWidget {
  final VoidCallback onTap;
  const _LogFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppTheme.accentRose,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: AppTheme.white, size: 22),
            SizedBox(width: 8),
            Text(
              'We did something!',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
