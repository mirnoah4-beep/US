import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
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
    final s = context.watch<LanguageProvider>().s;
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
                  _buildHeader(s),
                  const SizedBox(height: 18),
                  _buildLegend(s),
                  const SizedBox(height: 14),
                  _StatsBar(state: state),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final left = index * 2;
                    final right = left + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 110),
                                child: HeatCard(
                                  key: ValueKey(moments[left].id),
                                  item: moments[left],
                                  onTap: () => _openActivitySheet(context, moments[left], state),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: right < moments.length
                                  ? ConstrainedBox(
                                      constraints: const BoxConstraints(minHeight: 110),
                                      child: HeatCard(
                                        key: ValueKey(moments[right].id),
                                        item: moments[right],
                                        onTap: () => _openActivitySheet(context, moments[right], state),
                                      ),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: (moments.length / 2).ceil(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.lastTimeTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.lastTimeSubtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(s) {
    return Row(
      children: [
        _legendChip(AppTheme.heatGreenText, AppTheme.heatGreenBg,
            AppTheme.heatGreenBorder, s.lastTime07),
        const SizedBox(width: 8),
        _legendChip(AppTheme.heatAmberText, AppTheme.heatAmberBg,
            AppTheme.heatAmberBorder, s.lastTime814),
        const SizedBox(width: 8),
        _legendChip(AppTheme.heatRedText, AppTheme.heatRedBg,
            AppTheme.heatRedBorder, s.lastTime15),
      ],
    );
  }

  Widget _legendChip(
      Color text, Color bg, Color border, String label) {
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
              decoration:
                  BoxDecoration(color: text, shape: BoxShape.circle),
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

  void _openActivitySheet(
      BuildContext context, MomentItem item, AppState state) {
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
    final s = context.watch<LanguageProvider>().s;
    final count = state.momentCountThisMonth;
    final streak = state.streakWeeks;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBeige,
        borderRadius: BorderRadius.circular(14),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.bar_chart,
              color: AppTheme.textSecondary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${s.lastTimeStat(count)}  ·  ${s.lastTimeStreak(streak)}',
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
    final s = context.watch<LanguageProvider>().s;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppTheme.accentRose,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded,
                color: AppTheme.white, size: 22),
            const SizedBox(width: 8),
            Text(
              s.lastTimeLogButton,
              style: const TextStyle(
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
