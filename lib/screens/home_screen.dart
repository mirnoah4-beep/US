import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/relationship_battery_card.dart';
import '../widgets/goal_card.dart';
import '../widgets/log_moment_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openLogSheet(BuildContext context) {
    final state = context.read<AppState>();
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 24),
            _buildHeader(context),
            const SizedBox(height: 28),
            RelationshipBatteryCard(
              percent: state.batteryPercent,
              message: state.batteryMessage,
            ),
            const SizedBox(height: 16),
            _buildGoalRow(context, state),
            const SizedBox(height: 16),
            _buildSuggestionCard(context, state),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentRose,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'US',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _openSettings(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Make time for us.',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'More quality. Less chaos. More us.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalRow(BuildContext context, AppState state) {
    return Row(
      children: [
        Expanded(
          child: GoalCard(
            label: 'This week',
            current: state.weeklyDates,
            total: AppState.weeklyDateGoal,
            sublabel: 'dates',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GoalCard(
            label: 'This month',
            current: state.monthlyDates,
            total: AppState.monthlyDateGoal,
            sublabel: 'dates',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LastDateCard(daysAgo: state.lastDateMoment.daysAgo),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(BuildContext context, AppState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentRose.withValues(alpha: 0.08),
            AppTheme.accentRoseLight.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentRoseLight, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Suggestion for tonight',
                  style: TextStyle(
                    color: AppTheme.accentRose,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Mini-date tonight',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tea + question cards, 20 min',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showSnackbar(context, 'Suggestion sent!'),
                  child: const Text('Send suggestion'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openLogSheet(context),
                  child: const Text('Log a moment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(state: state),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final AppState state;
  const _SettingsSheet({required this.state});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _hasChildren;

  @override
  void initState() {
    super.initState();
    _hasChildren = widget.state.hasChildren;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
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
          const Text(
            'Settings',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.child_friendly_rounded, color: AppTheme.textSecondary, size: 22),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'We have children',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Show parent-specific ideas and moments',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hasChildren,
                  onChanged: (val) {
                    setState(() => _hasChildren = val);
                    widget.state.setHasChildren(val);
                  },
                  activeThumbColor: AppTheme.accentRose,
                  activeTrackColor: AppTheme.accentRoseLight,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
