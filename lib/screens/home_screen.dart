import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/relationship_battery_card.dart';
import '../widgets/goal_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            const SizedBox(height: 20),
            RelationshipBatteryCard(
              percent: state.batteryPercent,
              statusLine: state.batteryStatusLine,
              message: state.batteryMessage,
            ),
            const SizedBox(height: 12),
            if (state.hasChildren) ...[
              _buildAloneTimeCard(),
              const SizedBox(height: 12),
              _buildKidsBedtimeCard(),
              const SizedBox(height: 12),
            ],
            _buildGoalRow(state),
            const SizedBox(height: 12),
            _buildSuggestionCard(context),
            const SizedBox(height: 12),
            _buildInspirationCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'US',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Hi, you two! 👋',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Small moments create strong bonds.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
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
    );
  }

  Widget _buildAloneTimeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accentRoseLight,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: const [
          Icon(Icons.hourglass_bottom_rounded, color: AppTheme.accentRose, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You haven\'t had alone time in 12 days.',
              style: TextStyle(
                color: AppTheme.accentRose,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidsBedtimeCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEE6F5),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: const [
          Text('🌙', style: TextStyle(fontSize: 18)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'The kids will be asleep soon',
              style: TextStyle(
                color: Color(0xFF7B5EA7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          Text(
            'Plan something',
            style: TextStyle(
              color: Color(0xFF7B5EA7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(AppState state) {
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

  Widget _buildSuggestionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentRose.withValues(alpha: 0.07),
            AppTheme.accentRoseLight.withValues(alpha: 0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.accentRoseLight, width: 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 10),
          const Text(
            'Mini-date tonight',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'cards + tea, 20 min',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
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
                  onPressed: () => _showSnackbar(context, 'You\'re in! 🎉'),
                  child: const Text('I\'m in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspirationCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBeige,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentGreenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.format_quote_rounded, color: AppTheme.accentGreen, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s inspiration',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '"A great relationship is about two things: finding the similarities and respecting the differences."',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
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
