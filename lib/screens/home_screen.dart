import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/relationship_battery_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 112),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 18),
            Text(
              _timeGreeting(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _dateLine(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 22),
            _buildReminderCard(),
            const SizedBox(height: 16),
            RelationshipBatteryCard(
              percent: state.batteryPercent,
              statusLine: state.batteryStatusLine,
              message: 'Recharge with small moments tonight.',
            ),
            const SizedBox(height: 22),
            _sectionTitle('Tonight’s idea'),
            const SizedBox(height: 9),
            _buildTonightIdeaCard(context),
            const SizedBox(height: 22),
            _sectionTitle('This week'),
            const SizedBox(height: 9),
            _buildWeekGrid(state),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'US',
            style: TextStyle(
              color: AppTheme.accentRose,
              fontSize: 32,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.6,
              height: 1,
              fontFamily: 'Georgia',
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openSettings(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.065),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textPrimary,
              size: 23,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.accentRoseLight.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: AppTheme.accentRose,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'A small compliment can brighten the day for both of you.',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
      ),
    );
  }

  Widget _buildTonightIdeaCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentRose.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mini-date',
                      style: TextStyle(
                        color: AppTheme.accentRose,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Cards + tea',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '20 min · just you two',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                height: 78,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 56,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.accentRoseLight.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.local_cafe_rounded,
                          color: AppTheme.accentRose,
                          size: 31,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2,
                      bottom: 5,
                      child: Transform.rotate(
                        angle: -0.18,
                        child: Container(
                          width: 47,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.textPrimary.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: AppTheme.accentRose,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _showSnack(context, 'Idea sent!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
                foregroundColor: AppTheme.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              child: const Text(
                'Send idea',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _openCustomMessageSheet(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.white.withValues(alpha: 0.55),
                foregroundColor: AppTheme.accentRose,
                side: BorderSide(color: AppTheme.accentRose.withValues(alpha: 0.18)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              child: const Text(
                'Write your own',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekGrid(AppState state) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.12,
      children: [
        _WeekTile(
          icon: Icons.home_rounded,
          title: 'Home date',
          subtitle: '${state.weeklyDates} of ${AppState.weeklyDateGoal} done',
          iconColor: AppTheme.accentRose,
          iconBg: AppTheme.accentRoseLight,
        ),
        _WeekTile(
          icon: Icons.directions_walk_rounded,
          title: 'Walk together',
          subtitle: '${state.weeklyWalks} of ${AppState.weeklyWalkGoal} done',
          iconColor: AppTheme.accentGreen,
          iconBg: AppTheme.accentGreenLight,
          complete: state.weeklyWalks >= AppState.weeklyWalkGoal,
        ),
        _WeekTile(
          icon: Icons.phonelink_erase_rounded,
          title: 'Phone-free talk',
          subtitle: '${state.weeklyPhoneFreeTalks} of ${AppState.weeklyPhoneFreeTalkGoal} done',
          iconColor: AppTheme.warningAmber,
          iconBg: AppTheme.warningAmberLight,
        ),
        const _WeekTile(
          icon: Icons.add_rounded,
          title: 'Add goal',
          subtitle: 'Plan together',
          iconColor: AppTheme.textSecondary,
          iconBg: AppTheme.divider,
        ),
      ],
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning, you two! 👋';
    if (hour >= 12 && hour < 17) return 'Good afternoon, you two! 👋';
    if (hour >= 17 && hour < 22) return 'Good evening, you two! 👋';
    return 'Still awake, you two? 🌙';
  }

  String _dateLine() {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]} · ${now.day} ${months[now.month - 1]}';
  }

  void _openCustomMessageSheet(BuildContext context) {
    final controller = TextEditingController(
      text: 'Want to take 20 minutes for us tonight?',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Write your own',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Make it sound like you.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.white,
                      hintText: 'Write your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showSnack(context, 'Custom idea sent!');
                      },
                      child: const Text(
                        'Send custom idea',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(BuildContext context, String message) {
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

class _WeekTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final bool complete;

  const _WeekTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    this.complete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: complete ? AppTheme.accentGreen : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: complete ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (complete) ...[
            const SizedBox(width: 7),
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppTheme.accentGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
