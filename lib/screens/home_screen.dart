import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/weekly_idea.dart';
import '../models/weekly_ideas_provider.dart';
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
            const SizedBox(height: 16),
            const _WeeklyIdeasSection(),
            const SizedBox(height: 4),
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

// ─── Weekly Ideas Section ────────────────────────────────────────────────────

class _WeeklyIdeasSection extends StatefulWidget {
  const _WeeklyIdeasSection();

  @override
  State<_WeeklyIdeasSection> createState() => _WeeklyIdeasSectionState();
}

class _WeeklyIdeasSectionState extends State<_WeeklyIdeasSection> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  String? _shownIncomingRequestId;
  Set<String> _seenRequestIds = {};
  WeeklyIdeasProvider? _provider;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(() {
      final p = _pageCtrl.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });
    _loadSeenRequests();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      _provider = context.read<WeeklyIdeasProvider>();
      _provider!.addListener(_onProviderUpdate);
      _provider!.init(appState.coupleId);
      _provider!.checkIncomingRequests(appState.coupleId, appState.userId);
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderUpdate);
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSeenRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList('seenIdeaRequests') ?? [];
      _seenRequestIds = Set.from(seen);
    } catch (_) {}
  }

  Future<void> _markRequestSeen(String requestId) async {
    _seenRequestIds.add(requestId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seenIdeaRequests', _seenRequestIds.toList());
    } catch (_) {}
  }

  void _onProviderUpdate() {
    if (!mounted || _provider == null) return;
    final incoming = _provider!.incomingRequest;
    if (incoming != null &&
        incoming.requestId != _shownIncomingRequestId &&
        !_seenRequestIds.contains(incoming.requestId)) {
      _shownIncomingRequestId = incoming.requestId;
      _markRequestSeen(incoming.requestId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showIncomingSheet(incoming);
      });
    }
  }


  void _showIncomingSheet(IncomingIdeaRequest request) {
    final appState = context.read<AppState>();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final s = context.read<LanguageProvider>().s;
      showModalBottomSheet(
        context: context,
        useRootNavigator: false,
        isScrollControlled: true,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PartnerIdeaSheet(
          request: request,
          onAccept: () {
            _provider!.respondToRequest(
              appState.coupleId,
              request.requestId,
              true,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.ideaDoneAddedPlan),
                backgroundColor: const Color(0xFF3B6D11),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          onDecline: () => _provider!.respondToRequest(
            appState.coupleId,
            request.requestId,
            false,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeeklyIdeasProvider>();
    final s = context.watch<LanguageProvider>().s;
    final ideas = provider.ideas;

    Widget content;
    if (provider.loading && ideas.isEmpty) {
      content = const _WeeklyIdeasSkeleton();
    } else if (ideas.isEmpty) {
      content = _WeeklyIdeasEmpty(message: s.homeWeeklyIdeasEmpty);
    } else {
      content = Column(
        children: [
          SizedBox(
            height: 272.0,
            child: PageView.builder(
              controller: _pageCtrl,
              physics: const PageScrollPhysics(),
              itemCount: ideas.length,
              itemBuilder: (_, i) => Align(
                alignment: Alignment.topLeft,
                child: _WeeklyIdeaCard(
                  idea: ideas[i],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(ideas.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFC1544A)
                      : const Color(0xFFE0D9D0),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 6),
          _AiPill(label: s.homeAiPersonalized),
        ],
        const SizedBox(height: 8),
        content,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFE),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF534AB7),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WeeklyIdeaCard extends StatefulWidget {
  final WeeklyIdea idea;
  const _WeeklyIdeaCard({required this.idea});

  @override
  State<_WeeklyIdeaCard> createState() => _WeeklyIdeaCardState();
}

class _WeeklyIdeaCardState extends State<_WeeklyIdeaCard>
    with TickerProviderStateMixin {
  bool _waiting = false;
  bool _accepted = false;
  bool _declined = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;
  late ConfettiController _confettiCtrl;
  WeeklyIdeasProvider? _provider;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.35)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseCtrl);

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_heartCtrl);

    _confettiCtrl = ConfettiController(
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider?.removeListener(_onProviderUpdate);
    _provider = context.read<WeeklyIdeasProvider>();
    _provider!.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderUpdate);
    _pulseCtrl.dispose();
    _heartCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted || _provider == null || !_waiting) return;
    final state = _provider!.sendState;
    if (state == IdeaSendState.accepted) {
      _handleAccepted();
    } else if (state == IdeaSendState.declined) {
      _handleDeclined();
    } else if (state == IdeaSendState.idle) {
      // Expired externally (cancel sets _waiting=false before resetSendState fires)
      setState(() {
        _waiting = false;
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      });
    }
  }

  void _handleAccepted() {
    _pulseCtrl.stop();
    setState(() {
      _waiting = false;
      _accepted = true;
    });
    _confettiCtrl.play();
    _heartCtrl.forward();
    _writeToWeeklyPlan();
    // Defer so we're not calling notifyListeners inside a listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider?.resetSendState();
    });
  }

  void _handleDeclined() {
    _pulseCtrl.stop();
    setState(() {
      _waiting = false;
      _declined = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _declined = false);
        _provider?.resetSendState();
      }
    });
  }

  Future<void> _writeToWeeklyPlan() async {
    final appState = context.read<AppState>();
    try {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(appState.coupleId)
          .collection('weeklyPlan')
          .add({
        'ideaTitle': widget.idea.title,
        'ideaMeta': widget.idea.meta,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'both',
      });
    } catch (e) {
      debugPrint('writeToWeeklyPlan failed: $e');
    }
  }

  void _handleSend() {
    setState(() => _waiting = true);
    if (!MediaQuery.of(context).disableAnimations) _pulseCtrl.repeat();
    final appState = context.read<AppState>();
    context.read<WeeklyIdeasProvider>().sendIdea(
      widget.idea,
      appState.coupleId,
      appState.userId,
      appState.displayName,
    );
  }

  void _handleCancel() {
    setState(() => _waiting = false);
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    final appState = context.read<AppState>();
    context.read<WeeklyIdeasProvider>().cancelPendingIdea(appState.coupleId);
  }

  void _openWriteOwn() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _WriteYourOwnSheet(
          onSend: (text) {
            Navigator.pop(ctx);
            _handleCustomSend(text);
          },
        ),
      ),
    );
  }

  void _handleCustomSend(String text) {
    setState(() => _waiting = true);
    if (!MediaQuery.of(context).disableAnimations) _pulseCtrl.repeat();
    final appState = context.read<AppState>();
    final customIdea = WeeklyIdea(
      title: text,
      category: '',
      meta: '',
      cardColor: widget.idea.cardColor,
      tagColor: widget.idea.tagColor,
      tagTextColor: widget.idea.tagTextColor,
      icon: widget.idea.icon,
      description: '',
      buttonColor: widget.idea.buttonColor,
    );
    context.read<WeeklyIdeasProvider>().sendIdea(
      customIdea,
      appState.coupleId,
      appState.userId,
      appState.displayName,
    );
  }

  double _dotOpacity(double v, int index) {
    // stagger 0ms / 200ms / 400ms → 0 / 1/7 / 2/7 of 1400ms cycle
    final phase = ((v - index / 7.0) % 1.0 + 1.0) % 1.0;
    return 0.35 + 0.65 * sin(phase * pi).abs();
  }

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    final s = context.watch<LanguageProvider>().s;
    final partnerName = context.read<AppState>().partnerName;

    Widget bottomContent;
    if (_accepted) {
      bottomContent = _buildSuccess(s, partnerName, idea);
    } else if (_declined) {
      bottomContent = _buildDeclined(s, idea);
    } else if (_waiting) {
      bottomContent = _buildWaiting(s, partnerName, idea);
    } else {
      bottomContent = _buildIdle(s, idea);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: idea.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section — fixed 96px
              SizedBox(
                height: 96,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
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
                            const SizedBox(height: 7),
                            Text(
                              idea.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              idea.meta,
                              style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: 0.22,
                        child: Icon(idea.icon, size: 48, color: idea.tagTextColor),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom section — auto-sizes to content via IntrinsicHeight
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: anim.drive(
                            Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: bottomContent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 18,
              maxBlastForce: 12,
              minBlastForce: 3,
              emissionFrequency: 0.5,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                Color(0xFFC1544A),
                Color(0xFFEAF3DE),
                Color(0xFFFAEEDA),
                Color(0xFFF5C4B3),
                Color(0xFF3B6D11),
                Color(0xFFFAC775),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdle(dynamic s, WeeklyIdea idea) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 132),
      child: Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: _handleSend,
          icon: const Icon(Icons.send, size: 16),
          label: Text(
            s.homeIdeaSendToPartner,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: idea.buttonColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _openWriteOwn,
          style: OutlinedButton.styleFrom(
            foregroundColor: idea.tagTextColor,
            side: BorderSide(
                color: idea.tagTextColor.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          child: Text(
            s.homeWriteOwn,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildWaiting(dynamic s, String partnerName, WeeklyIdea idea) {
    return AnimatedBuilder(
      key: const ValueKey('waiting'),
      animation: _pulseCtrl,
      builder: (context, _) {
        final v = _pulseCtrl.value;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 130),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: _pulseAnim.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: idea.buttonColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: idea.buttonColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.ideaSentTo(partnerName),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              s.ideaWaitingLong,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: _dotOpacity(v, i).clamp(0.0, 1.0),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: idea.buttonColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _handleCancel,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                s.ideaCancel,
                style: TextStyle(
                  color: idea.tagTextColor,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  Widget _buildSuccess(dynamic s, String partnerName, WeeklyIdea idea) {
    return Column(
      key: const ValueKey('success'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _heartAnim,
          child: const Icon(
            Icons.favorite_border,
            size: 32,
            color: Color(0xFF3B6D11),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.ideaPartnerSaidYes(partnerName),
          style: const TextStyle(
            color: Color(0xFF27500A),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          s.ideaTonightNice,
          style: const TextStyle(
            color: Color(0xFF3B6D11),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            border: Border.all(color: const Color(0xFFC0DD97)),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFF3B6D11),
              ),
              const SizedBox(width: 6),
              Text(
                s.ideaAddedToPlan,
                style: const TextStyle(
                  color: Color(0xFF27500A),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeclined(dynamic s, WeeklyIdea idea) {
    return Column(
      key: const ValueKey('declined'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.sentiment_neutral_rounded,
          size: 28,
          color: idea.tagTextColor.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          s.ideaDeclinedTitle,
          style: TextStyle(
            color: idea.tagTextColor.withValues(alpha: 0.7),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Write your own bottom sheet ─────────────────────────────────────────────

class _WriteYourOwnSheet extends StatefulWidget {
  final void Function(String text) onSend;
  const _WriteYourOwnSheet({required this.onSend});

  @override
  State<_WriteYourOwnSheet> createState() => _WriteYourOwnSheetState();
}

class _WriteYourOwnSheetState extends State<_WriteYourOwnSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final canSend = _ctrl.text.trim().length >= 3;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD3D1C7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            s.ideaWriteOwnTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: null,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.ideaWriteOwnHint,
              hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D9D0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D9D0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFC1544A), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSend ? () => widget.onSend(_ctrl.text.trim()) : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC1544A),
                disabledBackgroundColor:
                    const Color(0xFFC1544A).withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor:
                    Colors.white.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.ideaSendToPartnerShort,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                s.ideaCancel,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _WeeklyIdeasSkeleton extends StatelessWidget {
  const _WeeklyIdeasSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppTheme.textMuted.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == 0 ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == 0
                  ? const Color(0xFFC1544A).withValues(alpha: 0.3)
                  : const Color(0xFFE0D9D0),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
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

// ─── Partner idea sheet (incoming request from partner) ──────────────────────

class _PartnerIdeaSheet extends StatelessWidget {
  final IncomingIdeaRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PartnerIdeaSheet({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  void _acceptPressed(BuildContext context) {
    Navigator.pop(context);
    onAccept();
  }

  void _declinePressed(BuildContext context) {
    Navigator.pop(context);
    onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFD3D1C7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFAECE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              s.ideaFromLabel(request.senderName),
              style: const TextStyle(
                color: Color(0xFF993C1D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            request.ideaTitle,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            request.ideaMeta,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0D9D0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              request.ideaDescription,
              style: const TextStyle(
                color: Color(0xFF5F5E5A),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _acceptPressed(context),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(s.ideaAcceptButtonText),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC1544A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declinePressed(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF888888),
                    side: const BorderSide(color: Color(0xFFE0D9D0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                  child: Text(s.ideaDeclineButtonText),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

