import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/relationship_battery_card.dart';
import 'resolve_together_screen.dart';
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 18),
            Text(
              _timeGreeting(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formattedDate(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 18),
            _buildInspirationCard(),
            const SizedBox(height: 14),
            RelationshipBatteryCard(
              percent: state.batteryPercent,
              statusLine: state.batteryStatusLine,
              message: state.batteryMessage,
            ),
            const SizedBox(height: 14),
            _buildResolveCard(context),
            const SizedBox(height: 22),
            _sectionLabel('Tonight\'s idea'),
            const SizedBox(height: 10),
            const _TonightCard(),
            const SizedBox(height: 22),
            _sectionLabel('This week'),
            const SizedBox(height: 10),
            _buildThisWeekGrid(state),
          ],
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning, you two! 👋';
    if (hour >= 12 && hour < 17) return 'Good afternoon, you two! 👋';
    if (hour >= 17 && hour < 22) return 'Good evening, you two! 👋';
    return 'Still awake, you two? 🌙';
  }

  String _formattedDate() {
    return DateFormat('EEEE, MMMM d').format(DateTime.now());
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/logo/us_wordmark.png',
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openSettings(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInspirationCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentRose.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: AppTheme.accentRose,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'A small compliment can brighten the day.',
              style: TextStyle(
                color: AppTheme.textPrimary,
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

  Widget _buildThisWeekGrid(AppState state) {
    final walkDone = state.weeklyWalks >= AppState.weeklyWalkGoal;
    final dateDone = state.weeklyDates >= AppState.weeklyDateGoal;
    final phoneDone = state.weeklyPhoneFreeTalks >= AppState.weeklyPhoneFreeTalkGoal;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _WeekCard(
                  icon: Icons.directions_walk,
                  title: 'Walk together',
                  subtitle: walkDone ? 'Done this week' : '0 of 1 this week',
                  done: walkDone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekCard(
                  icon: Icons.favorite_border,
                  title: 'Date night',
                  subtitle: dateDone ? 'Done this week' : '0 of 1 this week',
                  done: dateDone,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _WeekCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Phone-free talk',
                  subtitle: phoneDone ? 'Done this week' : '0 of 1 this week',
                  done: phoneDone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekCard(
                  icon: Icons.star_outline_rounded,
                  title: 'Send a note',
                  subtitle: '0 of 1 this week',
                  done: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResolveCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResolveTogetherScreen()),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentRose.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: AppTheme.accentRose,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ikke helt enig?',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'La Tom Arne hjelpe dere å finne midten',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

// ─── Tonight card with waiting state ────────────────────────────────────────

class _TonightCard extends StatefulWidget {
  const _TonightCard();

  @override
  State<_TonightCard> createState() => _TonightCardState();
}

class _TonightCardState extends State<_TonightCard>
    with SingleTickerProviderStateMixin {
  bool _waiting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseOpacity = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _sendIdea() {
    setState(() => _waiting = true);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) _pulseController.repeat();
  }

  String _dotsText(double v) {
    if (v < 1 / 3) return '.';
    if (v < 2 / 3) return '..';
    return '...';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E0),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentRose.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: _waiting ? _buildWaiting() : _buildIdle(context),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Mini-date',
                      style: TextStyle(
                        color: AppTheme.accentRose,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Cards + tea',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Georgia',
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '20 min · just you two',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('🍵', style: TextStyle(fontSize: 58, height: 1.0)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _sendIdea,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B2E2E),
              foregroundColor: AppTheme.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Send idea',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
              backgroundColor: AppTheme.white.withValues(alpha: 0.60),
              foregroundColor: AppTheme.textPrimary,
              side: BorderSide(
                color: AppTheme.textPrimary.withValues(alpha: 0.12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Write your own',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final dots = _dotsText(_pulseController.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRose.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Mini-date',
                          style: TextStyle(
                            color: AppTheme.accentRose,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Cards + tea',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Georgia',
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('🍵', style: TextStyle(fontSize: 58, height: 1.0)),
              ],
            ),
            const SizedBox(height: 16),
            // Waiting state
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.white.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: _pulseOpacity.value,
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppTheme.accentRose,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fingers crossed... S is thinking$dots',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Three indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulseDot(
                  color: AppTheme.accentRose,
                  scale: 0.7 + _pulseOpacity.value * 0.3,
                ),
                const SizedBox(width: 6),
                const _PulseDot(color: AppTheme.textMuted, scale: 1.0),
                const SizedBox(width: 6),
                const _PulseDot(color: AppTheme.textMuted, scale: 1.0),
              ],
            ),
          ],
        );
      },
    );
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
                        color: AppTheme.textSecondary, fontSize: 14),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Sent to S!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.textPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRose,
                        foregroundColor: AppTheme.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Send to S',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
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
}

class _PulseDot extends StatelessWidget {
  final Color color;
  final double scale;

  const _PulseDot({required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Week card ──────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;

  const _WeekCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppTheme.heatGreenText : AppTheme.textSecondary;
    final iconBg = done
        ? AppTheme.heatGreenBg
        : AppTheme.textSecondary.withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (done)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.heatGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.heatGreenText,
                    size: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: done ? AppTheme.heatGreenText : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
