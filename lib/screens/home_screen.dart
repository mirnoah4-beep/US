import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/strings.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/weekly_idea.dart';
import '../models/weekly_ideas_provider.dart';
import '../services/firestore_service.dart';
import '../services/idea_image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/relationship_battery_card.dart';
import 'mediator_chat_screen.dart';
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
            _buildDateAndDurationLine(s, state),
            const SizedBox(height: 18),
            _buildInspirationCard(s),
            const SizedBox(height: 14),
            RelationshipBatteryCard(
              percent: state.batteryPercent,
              statusLine: s.batteryStatus(state.batteryPercent),
              message: s.batteryMsg(state.batteryPercent),
            ),
            const SizedBox(height: 16),
            const _WeeklyIdeasCarousel(),
            const SizedBox(height: 16),
            _sectionLabel(s.homeThisWeekSection),
            const SizedBox(height: 10),
            _buildThisWeekGrid(context, state, s),
            const SizedBox(height: 22),
            _buildResolveCard(context, s),
          ],
        ),
      ),
    );
  }

  String _timeGreeting(AppStrings s) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return s.greetingMorning;
    if (hour >= 12 && hour < 17) return s.greetingAfternoon;
    if (hour >= 17 && hour < 22) return s.greetingEvening;
    return s.greetingNight;
  }

  Widget _buildDateAndDurationLine(AppStrings s, AppState state) {
    final now = DateTime.now();
    final dateStr = s.homeFormattedDate(now);
    final since = state.togetherSince;

    if (since == null) {
      return Text(
        dateStr,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    int years = now.year - since.year;
    int months = now.month - since.month;
    if (now.day < since.day) months--;
    if (months < 0) { years--; months += 12; }

    return Row(
      children: [
        const Icon(Icons.favorite, size: 11, color: AppTheme.accentRose),
        const SizedBox(width: 5),
        Text(
          '${s.homeDurationLine(years, months)} · $dateStr',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
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

  Widget _buildThisWeekGrid(BuildContext context, AppState state, s) {
    final walkDone = state.weeklyWalks >= AppState.weeklyWalkGoal;
    final dateDone = state.weeklyDates >= AppState.weeklyDateGoal;
    final phoneDone = state.weeklyPhoneFreeTalks >= AppState.weeklyPhoneFreeTalkGoal;

    void goToLastTime(String? momentId) =>
        context.read<AppState>().requestTabNavigation(1, highlightId: momentId);

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
                  onTap: () => goToLastTime('walk'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekCard(
                  icon: Icons.favorite_border,
                  title: s.homeDateNight,
                  subtitle: dateDone ? s.homeDoneThisWeek : s.homeWeeklyGoal,
                  done: dateDone,
                  onTap: () => goToLastTime('date_night'),
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
                  onTap: () => goToLastTime('phone_free'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekCard(
                  icon: Icons.star_outline_rounded,
                  title: s.homeSendNote,
                  subtitle: s.homeWeeklyGoal,
                  done: false,
                  onTap: () => goToLastTime('send_note'),
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
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const MediatorChatScreen()),
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
    Navigator.of(context, rootNavigator: true).push(
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
      useRootNavigator: false,
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

// ─── Weekly Ideas Carousel ──────────────────────────────────────────────────

class _WeeklyIdeasCarousel extends StatefulWidget {
  const _WeeklyIdeasCarousel();

  @override
  State<_WeeklyIdeasCarousel> createState() => _WeeklyIdeasCarouselState();
}

class _WeeklyIdeasCarouselState extends State<_WeeklyIdeasCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coupleId = context.read<AppState>().coupleId;
      if (coupleId.isNotEmpty) {
        context.read<WeeklyIdeasProvider>().init(coupleId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final ideas = context.watch<WeeklyIdeasProvider>().ideas.take(4).toList();
    final appState = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              s.homeWeeklyIdeasSection,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (ideas.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(ideas.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? const Color(0xFFA32D2D)
                          : const Color(0xFFDDDDDD),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (ideas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              s.homeWeeklyIdeasEmpty,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          )
        else
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _controller,
              itemCount: ideas.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.only(
                    right: i < ideas.length - 1 ? 12 : 0),
                child: _IdeaPageCard(
                  idea: ideas[i],
                  coupleId: appState.coupleId,
                  userId: appState.userId,
                  displayName: appState.displayName,
                  partnerName: appState.partnerName,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton(
            onPressed: () => _openWriteOwnSheet(context, s),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFFFF),
              foregroundColor: const Color(0xFFA32D2D),
              side: const BorderSide(color: Color(0xFFA32D2D), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              s.homeWriteOwn,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _openWriteOwnSheet(BuildContext context, AppStrings s) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.background,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
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
                      Navigator.pop(sheetCtx);
                      final name =
                          context.read<AppState>().partnerName;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(s.ideaSentTo(name)),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA32D2D),
                      foregroundColor: AppTheme.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      s.homeSendIdea,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Single idea card ─────────────────────────────────────────────────────────

class _IdeaPageCard extends StatefulWidget {
  final WeeklyIdea idea;
  final String coupleId;
  final String userId;
  final String displayName;
  final String partnerName;

  const _IdeaPageCard({
    required this.idea,
    required this.coupleId,
    required this.userId,
    required this.displayName,
    required this.partnerName,
  });

  @override
  State<_IdeaPageCard> createState() => _IdeaPageCardState();
}

class _IdeaPageCardState extends State<_IdeaPageCard>
    with TickerProviderStateMixin {
  String? _imageUrl;
  bool _declinedShown = false;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final id = IdeaImageService.toId(widget.idea.title);
    final url = await IdeaImageService.fetchCoverUrl(id);
    if (mounted && url != null) setState(() => _imageUrl = url);
  }

  void _onSend(BuildContext context) {
    final s = context.read<LanguageProvider>().s;
    context.read<WeeklyIdeasProvider>().sendIdea(
          widget.idea,
          widget.coupleId,
          widget.userId,
          widget.displayName,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.ideaSentTo(widget.partnerName)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onCancel(BuildContext context) {
    context.read<WeeklyIdeasProvider>().cancelPendingIdea(widget.coupleId);
  }

  Future<void> _onAddToPlan(BuildContext context) async {
    final s = context.read<LanguageProvider>().s;
    final provider = context.read<WeeklyIdeasProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: s.ideaAddToPlanDialogTitle,
    );
    if (date == null || !mounted) return;
    await FirestoreService.addPlan(
      coupleId: widget.coupleId,
      activity: widget.idea.title,
      date: date,
      sentBy: widget.userId,
    );
    if (!mounted) return;
    provider.resetSendState();
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.ideaAddedToPlan),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final provider = context.watch<WeeklyIdeasProvider>();
    final isMyIdea = provider.sentIdea?.title == widget.idea.title;
    final state = isMyIdea ? provider.sendState : IdeaSendState.idle;

    if (state == IdeaSendState.declined && !_declinedShown) {
      _declinedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.ideaDeclinedTitle),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.textPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.read<WeeklyIdeasProvider>().resetSendState();
      });
    }
    if (state == IdeaSendState.idle) _declinedShown = false;

    return LayoutBuilder(builder: (ctx, constraints) {
      final cardWidth = constraints.maxWidth;
      final imageWidth = cardWidth * 0.55;

      // ── Badge ───────────────────────────────────────────────────────────────
      Widget badge;
      if (state == IdeaSendState.accepted) {
        badge = Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            '✓ Godkjent',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        badge = Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFCF0EC),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            widget.idea.category,
            style: const TextStyle(
              color: Color(0xFFA32D2D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }

      // ── Duration line ───────────────────────────────────────────────────────
      final String durationText;
      final bool isPending = state == IdeaSendState.waiting;
      if (isPending) {
        final isNo = context.read<LanguageProvider>().isNorwegian;
        durationText = isNo
            ? 'Venter på ${widget.partnerName}'
            : 'Waiting for ${widget.partnerName}';
      } else if (state == IdeaSendState.accepted) {
        durationText = s.ideaPartnerSaidYes(widget.partnerName);
      } else {
        durationText = widget.idea.meta;
      }

      // ── Bottom button ───────────────────────────────────────────────────────
      Widget button;
      if (state == IdeaSendState.waiting) {
        button = GestureDetector(
          onTap: () => _onCancel(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFA32D2D)),
            ),
            child: Text(
              s.ideaCancel,
              style: const TextStyle(
                color: Color(0xFFA32D2D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      } else if (state == IdeaSendState.accepted) {
        button = GestureDetector(
          onTap: () => _onAddToPlan(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              '📅 Legg til plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      } else {
        button = GestureDetector(
          onTap: () => _onSend(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFA32D2D),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              s.homeSendIdea,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }

      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: imageWidth,
              child: Opacity(
                opacity: state == IdeaSendState.waiting ? 0.5 : 1.0,
                child: ClipPath(
                  clipper: _CardDiagonalClipper(),
                  child: _imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: const Color(0xFFE8D5C0)),
                          errorWidget: (context, url, error) =>
                              Container(color: const Color(0xFFE8D5C0)),
                        )
                      : Container(color: const Color(0xFFE8D5C0)),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: cardWidth * 0.50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badge,
                    const SizedBox(height: 6),
                    Text(
                      widget.idea.title,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Georgia',
                        height: 1.2,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      durationText,
                      style: TextStyle(
                        color: const Color(0xFF888888),
                        fontSize: isPending ? 11.0 : 12.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: AnimatedBuilder(
                          animation: _dotCtrl,
                          builder: (context, child) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (i) {
                              final start = i / 3.0;
                              final end = (i + 1) / 3.0;
                              final v = _dotCtrl.value;
                              final t = (v >= start && v < end)
                                  ? (v - start) / (end - start)
                                  : 0.0;
                              final dy = -sin(t * pi) * 5.0;
                              return Transform.translate(
                                offset: Offset(0, dy),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  margin:
                                      EdgeInsets.only(right: i < 2 ? 4 : 0),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFA32D2D),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    button,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─── Diagonal clip ────────────────────────────────────────────────────────────

class _CardDiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.18, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_CardDiagonalClipper old) => false;
}

// ─── Week card ──────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;

  const _WeekCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppTheme.heatGreenText : AppTheme.textSecondary;
    final iconBg = done
        ? AppTheme.heatGreenBg
        : AppTheme.textSecondary.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    ),  // Container
    );  // GestureDetector
  }
}
