import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/weekly_idea.dart';
import '../models/weekly_ideas_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/relationship_battery_card.dart';
import 'resolve_together_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.watch<LanguageProvider>().s;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 18),
            Text(
              _timeGreeting(s),
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
            _buildInspirationCard(s),
            const SizedBox(height: 14),
            RelationshipBatteryCard(
              percent: state.batteryPercent,
              statusLine: s.batteryStatus(state.batteryPercent),
              message: s.batteryMsg(state.batteryPercent),
            ),
            const SizedBox(height: 22),
            _sectionLabel(s.homeTonightSection),
            const SizedBox(height: 10),
            _TonightCard(s: s),
            const SizedBox(height: 22),
            _sectionLabel(s.homeThisWeekSection),
            const SizedBox(height: 10),
            _buildThisWeekGrid(state, s),
            const SizedBox(height: 22),
            const _WeeklyIdeasSection(),
            const SizedBox(height: 22),
            _buildResolveCard(context, s),
          ],
        ),
      ),
    );
  }

  String _timeGreeting(s) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return s.greetingMorning;
    if (hour >= 12 && hour < 17) return s.greetingAfternoon;
    if (hour >= 17 && hour < 22) return s.greetingEvening;
    return s.greetingNight;
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

  Widget _buildInspirationCard(s) {
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
          Expanded(
            child: Text(
              s.homeInspirationQuote,
              style: const TextStyle(
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

  Widget _buildThisWeekGrid(AppState state, s) {
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
                  title: s.homeWalkTogether,
                  subtitle: walkDone ? s.homeDoneThisWeek : s.homeWeeklyGoal,
                  done: walkDone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekCard(
                  icon: Icons.favorite_border,
                  title: s.homeDateNight,
                  subtitle: dateDone ? s.homeDoneThisWeek : s.homeWeeklyGoal,
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
                  title: s.homePhoneFreeTalk,
                  subtitle: phoneDone ? s.homeDoneThisWeek : s.homeWeeklyGoal,
                  done: phoneDone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekCard(
                  icon: Icons.star_outline_rounded,
                  title: s.homeSendNote,
                  subtitle: s.homeWeeklyGoal,
                  done: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResolveCard(BuildContext context, s) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.homeResolveTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.homeResolveSubtitle,
                    style: const TextStyle(
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
  final dynamic s;
  const _TonightCard({required this.s});

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
    final s = context.watch<LanguageProvider>().s;
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
      child: _waiting ? _buildWaiting(s) : _buildIdle(context, s),
    );
  }

  Widget _buildIdle(BuildContext context, s) {
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
                    child: Text(
                      s.homeTonightTag,
                      style: const TextStyle(
                        color: AppTheme.accentRose,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.homeTonightTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Georgia',
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.homeTonightSubtitle,
                    style: const TextStyle(
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
            child: Text(
              s.homeSendIdea,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () => _openCustomMessageSheet(context, s),
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
            child: Text(
              s.homeWriteOwn,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting(s) {
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
                        child: Text(
                          s.homeTonightTag,
                          style: const TextStyle(
                            color: AppTheme.accentRose,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.homeTonightTitle,
                        style: const TextStyle(
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
                      s.homeWaiting(dots),
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

  void _openCustomMessageSheet(BuildContext context, s) {
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
                  Text(
                    s.homeWriteOwnSheetTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.homeWriteOwnSheetSubtitle,
                    style: const TextStyle(
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
                      hintText: s.homeWriteOwnHint,
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
                            content: Text(s.homeSentToS),
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
                      child: Text(
                        s.homeSendToS,
                        style: const TextStyle(
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

// ─── Weekly Ideas Section ────────────────────────────────────────────────────

class _WeeklyIdeasSection extends StatefulWidget {
  const _WeeklyIdeasSection();

  @override
  State<_WeeklyIdeasSection> createState() => _WeeklyIdeasSectionState();
}

class _WeeklyIdeasSectionState extends State<_WeeklyIdeasSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coupleId = context.read<AppState>().coupleId;
      context.read<WeeklyIdeasProvider>().init(coupleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeeklyIdeasProvider>();
    final s = context.watch<LanguageProvider>().s;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              s.homeWeeklyIdeasSection,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (provider.isAiGenerated) ...[
              const SizedBox(width: 8),
              _AiPill(label: s.homeAiPersonalized),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (provider.loading && provider.ideas.isEmpty)
          const _WeeklyIdeasSkeleton()
        else if (provider.ideas.isEmpty)
          _WeeklyIdeasEmpty(message: s.homeWeeklyIdeasEmpty)
        else
          _WeeklyIdeasCarousel(ideas: provider.ideas),
      ],
    );
  }
}

class _AiPill extends StatelessWidget {
  final String label;
  const _AiPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFE),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF534AB7),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WeeklyIdeasCarousel extends StatelessWidget {
  final List<WeeklyIdea> ideas;
  const _WeeklyIdeasCarousel({required this.ideas});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: ideas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _WeeklyIdeaCard(idea: ideas[i]),
      ),
    );
  }
}

class _WeeklyIdeaCard extends StatelessWidget {
  final WeeklyIdea idea;
  const _WeeklyIdeaCard({required this.idea});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: idea.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: idea.tagColor,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              idea.category,
              style: TextStyle(
                color: idea.tagTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Icon(idea.icon, size: 22, color: idea.tagTextColor),
          const SizedBox(height: 8),
          Text(
            idea.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            idea.meta,
            style: TextStyle(
              color: idea.tagTextColor.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WeeklyIdeasSkeleton extends StatelessWidget {
  const _WeeklyIdeasSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 158,
          decoration: BoxDecoration(
            color: AppTheme.textMuted.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _WeeklyIdeasEmpty extends StatelessWidget {
  final String message;
  const _WeeklyIdeasEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
