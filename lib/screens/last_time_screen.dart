import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../l10n/strings.dart';
import '../models/language_provider.dart';
import '../models/moment_item.dart';
import '../theme/app_theme.dart';
import '../widgets/heat_card.dart';
import '../widgets/log_moment_sheet.dart';

class LastTimeScreen extends StatefulWidget {
  const LastTimeScreen({super.key});

  @override
  State<LastTimeScreen> createState() => _LastTimeScreenState();
}

class _LastTimeScreenState extends State<LastTimeScreen> {
  final Map<String, GlobalKey> _cardKeys = {};
  String? _lastHighlight;

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey());

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
    final highlightId = state.highlightMomentId;

    if (highlightId != null && highlightId != _lastHighlight) {
      _lastHighlight = highlightId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = _cardKeys[highlightId];
        final cardCtx = key?.currentContext;
        if (cardCtx != null) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            Scrollable.ensureVisible(
              // ignore: use_build_context_synchronously
              cardCtx,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.3,
            );
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(s),
                    const SizedBox(height: 14),
                    _StatsBar(state: state),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildGrid(moments, state, highlightId),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openLogSheet(context, state),
            icon: const Icon(Icons.add),
            label: Text(s.lastTimeLogButton),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC1544A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.lastTimeTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.lastTimeSubtitle,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<MomentItem> moments, AppState state, String? highlightId) {
    final rows = <Widget>[];
    for (int i = 0; i < moments.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      final right = i + 1 < moments.length ? moments[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 110),
                child: HeatCard(
                  key: _keyFor(moments[i].id),
                  item: moments[i],
                  onTap: () => _openLogSheet(context, state, preSelected: moments[i].id),
                  isHighlighted: highlightId == moments[i].id,
                  onHighlightDone: () {
                    _lastHighlight = null;
                    state.clearHighlight();
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: right != null
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 110),
                      child: HeatCard(
                        key: _keyFor(right.id),
                        item: right,
                        onTap: () => _openLogSheet(context, state, preSelected: right.id),
                        isHighlighted: highlightId == right.id,
                        onHighlightDone: () {
                          _lastHighlight = null;
                          state.clearHighlight();
                        },
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  void _openLogSheet(BuildContext context, AppState state, {String? preSelected}) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D9D0), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_outlined,
              color: Color(0xFFC1544A), size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${s.lastTimeStat(count)}  ·  ${s.lastTimeStreak(streak)}',
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
