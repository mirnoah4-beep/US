import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 24),
            _buildHeader(),
            const SizedBox(height: 20),
            _buildPlanCard(context, state),
            const SizedBox(height: 16),
            _buildCoupleGameCard(context),
            const SizedBox(height: 16),
            _buildWeeklyReminderCard(),
            const SizedBox(height: 40),
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
          'This week',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Your shared intentions.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildPlanCard(BuildContext context, AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Our plan this week',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Both partners can approve a plan before it becomes active.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          _PlanProgressRow(
            label: '1 home date',
            current: state.weeklyDates,
            goal: AppState.weeklyDateGoal,
            icon: Icons.home_rounded,
          ),
          const SizedBox(height: 14),
          _PlanProgressRow(
            label: '1 walk',
            current: state.weeklyWalks,
            goal: AppState.weeklyWalkGoal,
            icon: Icons.directions_walk_rounded,
          ),
          const SizedBox(height: 14),
          _PlanProgressRow(
            label: '1 phone-free talk',
            current: state.weeklyPhoneFreeTalks,
            goal: AppState.weeklyPhoneFreeTalkGoal,
            icon: Icons.chat_bubble_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleGameCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B6E9E).withValues(alpha: 0.10),
            const Color(0xFFB59EC0).withValues(alpha: 0.20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4C8DE), width: 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEEE6F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF8B6E9E), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Couple game',
                  style: TextStyle(color: Color(0xFF8B6E9E), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 3),
                Text(
                  'Who knows whom best?',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showGameSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6E9E),
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyReminderCard() {
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
              color: AppTheme.warningAmberLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: AppTheme.warningAmber, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly reminder',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sunday evening — plan your week together.',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '10 min, before the week starts.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGameSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GameSheet(),
    );
  }
}

class _PlanProgressRow extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final IconData icon;

  const _PlanProgressRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.icon,
  });

  bool get _isComplete => current >= goal;
  double get _progress => (current / goal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _isComplete ? AppTheme.accentGreenLight : AppTheme.cardBeige,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isComplete ? Icons.check_rounded : icon,
            color: _isComplete ? AppTheme.accentGreen : AppTheme.textSecondary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$current/$goal',
                    style: TextStyle(
                      color: _isComplete ? AppTheme.accentGreen : AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isComplete ? AppTheme.accentGreen : AppTheme.accentRose,
                  ),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameSheet extends StatefulWidget {
  const _GameSheet();

  @override
  State<_GameSheet> createState() => _GameSheetState();
}

class _GameSheetState extends State<_GameSheet> {
  static const _questions = [
    'What is their favorite way to unwind after a tough day?',
    'Name one thing they\'ve always wanted to try together.',
    'What is their love language?',
    'What song reminds them of the early days?',
    'What do they consider a perfect Sunday morning?',
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Who knows whom best?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${_index + 1}/${_questions.length}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(20)),
            child: Text(
              _questions[_index],
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w500, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_index > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _index--),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_index < _questions.length - 1) {
                      setState(() => _index++);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(_index < _questions.length - 1 ? 'Next' : 'Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
