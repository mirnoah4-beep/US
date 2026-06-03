import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/strings.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/memories_provider.dart';
import '../models/memory_model.dart';
import '../models/weekly_idea.dart';
import '../models/weekly_ideas_provider.dart';
import '../services/firestore_service.dart';
import '../services/idea_image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_memory_sheet.dart';
import '../widgets/already_pending_dialog.dart';
import '../widgets/calendar_card.dart';
import '../widgets/heart_confirm_dialog.dart';
import '../widgets/relationship_battery_card.dart';
import 'couple_setup_screen.dart';
import 'memories_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.watch<LanguageProvider>().s;
    final hasPartner = state.partnerId.isNotEmpty;
    final memProv = context.watch<MemoriesProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 18),
            Text(
              s.homeFormattedDate(DateTime.now()),
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeGreeting(s, state.displayName, state.partnerName),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 18),
            if (!hasPartner && !_bannerDismissed) ...[
              _InviteBanner(
                onTap: () => _openInviteFlow(context, state.userId),
                onDismiss: () => setState(() => _bannerDismissed = true),
              ),
              const SizedBox(height: 8),
            ],
            if (hasPartner) ...[
              const _RelationshipCounterCard(),
              const SizedBox(height: 8),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: _NextPlanPill(),
            ),
            const SizedBox(height: 6),
            if (hasPartner) ...[
              RelationshipBatteryCard(
                percent: state.batteryPercent,
                statusLine: s.batteryStatus(state.batteryPercent),
                message: s.batteryMsg(state.batteryPercent),
              ),
              const SizedBox(height: 16),
            ],
            const _WeeklyIdeasCarousel(),
            if (!hasPartner) ...[
              const SizedBox(height: 20),
              _SoloPreviewGrid(s: s),
            ],
            if (hasPartner) ...[
              const SizedBox(height: 20),
              if (memProv.pendingPrompt != null)
                _MemoryPromptCard(
                  prompt: memProv.pendingPrompt!,
                  coupleId: state.coupleId,
                  userId: state.userId,
                  onDismiss: () =>
                      memProv.dismissPrompt(memProv.pendingPrompt!.planId),
                ),
              if (memProv.pendingPrompt != null) const SizedBox(height: 16),
              _buildMemoriesHeader(context, s, memProv.streakCount),
              const SizedBox(height: 10),
              if (memProv.memories.isEmpty)
                _MemoriesEmptyCard(s: s)
              else
                _MemoriesPreview(
                  memories: memProv.memories,
                  s: s,
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openInviteFlow(BuildContext context, String userId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CoupleSetupScreen(
          currentUserId: userId,
          onCoupleActive: () {},
        ),
      ),
    );
  }

  String _timeGreeting(AppStrings s, String name, String partnerName) {
    final names = s.greetingNames(name, partnerName);
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return s.greetingMorning(names);
    if (hour >= 12 && hour < 17) return s.greetingAfternoon(names);
    if (hour >= 17 && hour < 22) return s.greetingEvening(names);
    return s.greetingNight(names);
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

  Widget _buildMemoriesHeader(
      BuildContext context, AppStrings s, int streakCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          s.memoriesSection,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (streakCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 12, color: Color(0xFFBA7517)),
                const SizedBox(width: 3),
                Text(
                  '$streakCount',
                  style: const TextStyle(
                    color: Color(0xFFBA7517),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const MemoriesScreen()),
          ),
          child: Text(
            s.memoriesSeeAll,
            style: const TextStyle(
              color: Color(0xFFA32D2D),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

// ─── Memory prompt card ──────────────────────────────────────────────────────

class _MemoryPromptCard extends StatelessWidget {
  final MemoryPrompt prompt;
  final String coupleId;
  final String userId;
  final VoidCallback onDismiss;

  const _MemoryPromptCard({
    required this.prompt,
    required this.coupleId,
    required this.userId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final displayActivity = s.planActivityLabel(prompt.activity);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF0EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFA32D2D).withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFA32D2D), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.memoriesPromptTitle(displayActivity),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close,
                      color: AppTheme.textMuted, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => AddMemorySheet(
                          coupleId: coupleId,
                          createdBy: userId,
                          activity: displayActivity,
                          onDone: onDismiss,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA32D2D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      s.memoriesAddMemory,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(
                          color: AppTheme.textMuted.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      s.memoriesSkip,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Memories empty card ──────────────────────────────────────────────────────

class _MemoriesEmptyCard extends StatelessWidget {
  final AppStrings s;
  const _MemoriesEmptyCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined,
              size: 36, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(
            s.memoriesEmpty,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.memoriesEmptySub,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Memories preview (featured + strip) ─────────────────────────────────────

class _MemoriesPreview extends StatelessWidget {
  final List<MemoryModel> memories;
  final AppStrings s;
  const _MemoriesPreview({required this.memories, required this.s});

  void _openMemory(BuildContext context, AppState state, MemoryModel memory) {
    final s = context.read<LanguageProvider>().s;
    if (memory.imageUrl == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddMemorySheet(
          coupleId: state.coupleId,
          createdBy: state.userId,
          activity: s.readableActivity(memory.activity),
          memoryId: memory.id,
          initialNote: memory.note,
        ),
      );
    } else {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => _MemoryDetailInline(memory: memory, s: s),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = memories.first;
    final rest = memories.skip(1).take(3).toList();
    final appState = context.read<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured card
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openMemory(context, appState, featured),
          child: Container(
            height: featured.imageUrl != null ? 140.0 : null,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: featured.imageUrl != null
                ? _FeaturedWithImage(memory: featured, s: s)
                : _FeaturedNoImage(memory: featured, s: s),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => _openMemory(context, appState, rest[i]),
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D5C0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: rest[i].imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: rest[i].imageUrl!,
                          fit: BoxFit.cover,
                          fadeInDuration:
                              const Duration(milliseconds: 200),
                        )
                      : const Center(
                          child: Icon(
                            Icons.photo_camera_rounded,
                            color: Color(0xFF993C1D),
                            size: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedWithImage extends StatelessWidget {
  final MemoryModel memory;
  final AppStrings s;
  const _FeaturedWithImage({required this.memory, required this.s});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: memory.imageUrl!,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 200),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
                stops: [0.0, 0.65],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.readableActivity(memory.activity),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Georgia',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  s.memoriesRelativeDate(memory.createdAt),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedNoImage extends StatelessWidget {
  final MemoryModel memory;
  final AppStrings s;
  const _FeaturedNoImage({required this.memory, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image placeholder area
        Container(
          height: 140,
          color: const Color(0xFFE8D5C0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_camera_rounded,
                  color: Color(0xFF993C1D), size: 28),
              const SizedBox(height: 6),
              Text(
                s.memoriesAddPhoto,
                style: const TextStyle(
                  color: Color(0xFFA32D2D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Text area
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      s.readableActivity(memory.activity),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Georgia',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.memoriesRelativeDate(memory.createdAt),
                    style: const TextStyle(
                        color: AppTheme.textSubtle, fontSize: 12),
                  ),
                ],
              ),
              if (memory.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  memory.note,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Memory detail (inline wrapper — reuses MemoriesScreen detail) ────────────

class _MemoryDetailInline extends StatelessWidget {
  final MemoryModel memory;
  final AppStrings s;
  const _MemoryDetailInline({required this.memory, required this.s});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (memory.imageUrl != null)
            CachedNetworkImage(
              imageUrl: memory.imageUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
            )
          else
            const Center(
              child: Icon(Icons.photo_library_outlined,
                  color: Colors.white38, size: 72),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                  stops: [0.0, 0.6],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.readableActivity(memory.activity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.memoriesRelativeDate(memory.createdAt),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                  if (memory.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      memory.note,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Invite banner (shown to solo users until partner connects) ──────────────

class _InviteBanner extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InviteBanner({required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFCF0EC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFA32D2D).withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFA32D2D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.inviteBannerTitle,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.inviteBannerSubtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(6, 6, 0, 6),
                    child: Icon(Icons.close, color: AppTheme.textMuted, size: 16),
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

// ─── Tonight card with waiting state ────────────────────────────────────────

class _TonightCard extends StatefulWidget {
  final dynamic s;
  const _TonightCard({required this.s});

  @override
  State<_TonightCard> createState() => _TonightCardState();
}

class _TonightCardState extends State<_TonightCard>
    with SingleTickerProviderStateMixin {
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
    final appState = context.read<AppState>();
    if (appState.partnerId.isEmpty) {
      final isNo = context.read<LanguageProvider>().isNorwegian;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isNo ? 'Ingen partner koblet til' : 'No partner linked'),
        backgroundColor: AppTheme.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    context.read<WeeklyIdeasProvider>().sendIdea(
      const WeeklyIdea(
        titleNo: 'Kort + te',
        titleEn: 'Cards + tea',
        categoryNo: '',
        categoryEn: '',
        metaNo: '',
        metaEn: '',
        descriptionNo: '20 min · bare dere to',
        descriptionEn: '20 min · just you two',
        cardColor: Colors.white,
        tagColor: Color(0xFFFFE8E0),
        tagTextColor: Color(0xFF8B2E2E),
        icon: Icons.nights_stay_outlined,
        buttonColor: Color(0xFF8B2E2E),
      ),
      appState.coupleId,
      appState.userId,
      appState.displayName,
      partnerId: appState.partnerId,
      coverImageUrl: null,
    );
  }

  String _dotsText(double v) {
    if (v < 1 / 3) return '.';
    if (v < 2 / 3) return '..';
    return '...';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final provider = context.watch<WeeklyIdeasProvider>();
    final isWaiting = provider.sendState == IdeaSendState.waiting;

    if (isWaiting && !_pulseController.isAnimating) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (!reduceMotion) _pulseController.repeat();
    } else if (!isWaiting && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

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
      child: isWaiting ? _buildWaiting(s) : _buildIdle(context, s),
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
                    maxLength: 200,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
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
  bool _precaching = false;
  String _precachedKey = '';
  bool _customAcceptedShown = false;

  Future<void> _precacheAllImages(
      BuildContext ctx, List<WeeklyIdea> ideas) =>
      Future.wait(ideas.map((idea) async {
        final url = IdeaImageService.getCachedUrl(
            IdeaImageService.toId(idea.titleNo));
        if (url != null) {
          try {
            await precacheImage(
                CachedNetworkImageProvider(url, maxWidth: 600), ctx);
          } catch (_) {}
        }
      }));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final provider = context.watch<WeeklyIdeasProvider>();
    final ideas = provider.ideas
        .where((idea) => idea.titleNo.isNotEmpty || idea.titleEn.isNotEmpty)
        .take(4)
        .toList();
    final appState = context.watch<AppState>();

    // init() is idempotent — safe to call on every build.
    // Calling here (not initState) ensures it fires once coupleId is available,
    // which arrives asynchronously via Firestore after the first frame.
    if (appState.coupleId.isNotEmpty) {
      context.read<WeeklyIdeasProvider>().init(appState.coupleId);
    }

    final sentTitle = provider.sentIdea?.titleNo;
    final isCustomPending = provider.sendState == IdeaSendState.waiting &&
        !ideas.any((idea) => idea.titleNo == sentTitle);
    if (sentTitle != null && !ideas.any((idea) => idea.titleNo == sentTitle)) {
      if (provider.sendState == IdeaSendState.declined) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<WeeklyIdeasProvider>().resetSendState();
        });
      } else if (provider.sendState == IdeaSendState.accepted && !_customAcceptedShown) {
        _customAcceptedShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final nav = Navigator.of(context, rootNavigator: true);
          final provRef = context.read<WeeklyIdeasProvider>();
          final ls = context.read<LanguageProvider>().s;
          final appState = context.read<AppState>();
          final displayTitle = ls.ideaPartnerAcceptedTitle(
              appState.partnerName, sentTitle);
          nav.push(RawDialogRoute<void>(
            pageBuilder: (ctx, anim, secAnim) => HeartConfirmDialog(
              displayTitle: displayTitle,
              date: provRef.acceptedPlanDate,
              s: ls,
            ),
            barrierDismissible: true,
            barrierColor: Colors.black.withValues(alpha: 0.35),
            barrierLabel: 'Dismiss',
            transitionDuration: Duration.zero,
          ));
          Future.delayed(const Duration(milliseconds: 2700), provRef.resetSendState);
        });
      }
    }
    if (provider.sendState == IdeaSendState.idle) _customAcceptedShown = false;

    // Fix 4: surface send errors as a SnackBar.
    final sendError = provider.sendError;
    if (sendError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WeeklyIdeasProvider>().clearSendError();
        final isNo = context.read<LanguageProvider>().isNorwegian;
        final msg = sendError == 'noPartner'
            ? (isNo ? 'Ingen partner koblet til' : 'No partner linked')
            : (isNo ? 'Noe gikk galt – prøv igjen' : 'Something went wrong – try again');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      });
    }

    final key = ideas.map((e) => e.titleNo).join(',');
    final imagesReady = _precachedKey == key;

    if (ideas.isNotEmpty && !_precaching && !imagesReady) {
      _precaching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _precacheAllImages(context, ideas);
        if (mounted) setState(() { _precachedKey = key; _precaching = false; });
      });
    }

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
            if (ideas.isNotEmpty && (imagesReady || appState.coupleId.isEmpty))
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
        if (!imagesReady && appState.coupleId.isNotEmpty)
          const SizedBox(height: 160)
        else if (ideas.isEmpty)
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
                  hasPartner: appState.partnerId.isNotEmpty,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (isCustomPending)
          _WriteOwnWaitingBar(
            coupleId: appState.coupleId,
            partnerName: appState.partnerName,
          )
        else
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  void _openWriteOwnSheet(BuildContext context, AppStrings s) {
    if (context.read<AppState>().partnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.soloSendDisabledHint),
        backgroundColor: AppTheme.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WriteOwnSheet(),
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
  final bool hasPartner;

  const _IdeaPageCard({
    required this.idea,
    required this.coupleId,
    required this.userId,
    required this.displayName,
    required this.partnerName,
    required this.hasPartner,
  });

  @override
  State<_IdeaPageCard> createState() => _IdeaPageCardState();
}

class _IdeaPageCardState extends State<_IdeaPageCard>
    with TickerProviderStateMixin {
  String? _imageUrl;
  bool _urlWasKnownAtInit = false;
  bool _declinedShown = false;
  bool _acceptedShown = false;
  late AnimationController _dotCtrl;
  late AnimationController _slideCtrl;
  bool _onTimePage = false;
  DateTime? _proposedDate;
  TimeOfDay? _proposedTime;

  @override
  void initState() {
    super.initState();
    _imageUrl = IdeaImageService.getCachedUrl(IdeaImageService.toId(widget.idea.titleNo));
    _urlWasKnownAtInit = _imageUrl != null;
    if (_imageUrl == null) _loadImage();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final id = IdeaImageService.toId(widget.idea.titleNo);
    final url = await IdeaImageService.fetchCoverUrl(id);
    if (mounted && url != null) setState(() => _imageUrl = url);
  }

  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.uid == adminUid;

  Future<void> _pickAndUpload(BuildContext context) async {
    final s = context.read<LanguageProvider>().s;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;
    // Capture messenger before any await — ScaffoldMessenger survives widget
    // disposal, so success/error feedback fires even if the card is rebuilt.
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(s.adminUploading),
      duration: const Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final ideaId = IdeaImageService.toId(widget.idea.titleNo);
      final url = await IdeaImageService.uploadCover(ideaId, picked);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(s.adminUploadSuccess),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3B6D11),
      ));
      if (!context.mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
    }
  }

  void _onSend(BuildContext context) {
    setState(() {
      _onTimePage = true;
      _proposedDate = null;
      _proposedTime = null;
    });
    _slideCtrl.forward();
  }

  void _goBack() {
    _slideCtrl.reverse();
    setState(() => _onTimePage = false);
  }

  Future<void> _pickDate(BuildContext context) async {
    final s = context.read<LanguageProvider>().s;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        var displayMonth = DateTime(
          (_proposedDate ?? today).year,
          (_proposedDate ?? today).month,
          1,
        );
        var selected = _proposedDate ?? today;

        return StatefulBuilder(
          builder: (_, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                CalendarCard(
                  displayMonth: displayMonth,
                  selectedDate: selected,
                  eventDates: const {},
                  s: s,
                  onPrevMonth: () => setSheetState(() {
                    displayMonth = DateTime(
                        displayMonth.year, displayMonth.month - 1, 1);
                  }),
                  onNextMonth: () => setSheetState(() {
                    displayMonth = DateTime(
                        displayMonth.year, displayMonth.month + 1, 1);
                  }),
                  onSelectDate: (date) {
                    setSheetState(() => selected = date);
                    setState(() => _proposedDate = date);
                    Navigator.pop(sheetCtx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final now = DateTime.now();
    final initial = _proposedTime != null
        ? DateTime(now.year, now.month, now.day,
                   _proposedTime!.hour, _proposedTime!.minute)
        : DateTime(now.year, now.month, now.day, now.hour, now.minute);
    var selected = initial;
    final isNo = context.read<LanguageProvider>().isNorwegian;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
          height: 280,
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: initial,
                  onDateTimeChanged: (dt) => selected = dt,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA32D2D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isNo ? 'Ferdig' : 'Done',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
    if (mounted) {
      setState(() => _proposedTime =
          TimeOfDay(hour: selected.hour, minute: selected.minute));
    }
  }

  Future<void> _onConfirmSend(BuildContext context) async {
    final provider = context.read<WeeklyIdeasProvider>();
    final s = context.read<LanguageProvider>().s;
    final appState = context.read<AppState>();
    if (provider.sendState == IdeaSendState.waiting) {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlreadyPendingDialog(
          pendingTitle: provider.sentIdea?.title(s.isNorwegian) ?? '',
          s: s,
        ),
      );
      if (confirmed != true || !mounted) return;
      final ok = await provider.cancelForReplacement(widget.coupleId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.isNorwegian
              ? 'Noe gikk galt – prøv igjen'
              : 'Something went wrong – try again'),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
    }
    DateTime? proposedAt;
    if (_proposedDate != null) {
      final d = _proposedDate!;
      final t = _proposedTime ?? const TimeOfDay(hour: 20, minute: 0);
      proposedAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }
    provider.sendIdea(
      widget.idea,
      widget.coupleId,
      widget.userId,
      widget.displayName,
      partnerId: appState.partnerId,
      coverImageUrl: _imageUrl,
      proposedAt: proposedAt,
    );
    _slideCtrl.reverse();
    setState(() {
      _onTimePage = false;
      _proposedDate = null;
      _proposedTime = null;
    });
  }

  Widget _buildTimeSide(BuildContext context, AppStrings s) {
    final dateLabel = _proposedDate != null
        ? '${_proposedDate!.day}.${_proposedDate!.month}'
        : s.ideaDatePlaceholder;
    final timeLabel = _proposedTime != null
        ? _proposedTime!.format(context)
        : s.ideaTimePlaceholder;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Stack(
        children: [
          // Back arrow pinned top-left
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: _goBack,
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppTheme.textSubtle),
            ),
          ),
          // All content vertically centered as a group
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: AutoSizeText(
                  widget.idea.title(s.isNorwegian),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Georgia',
                    height: 1.2,
                  ),
                  minFontSize: 13,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  s.ideaWhenWorksForYou,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              // Date + time buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        onPressed: () => _pickDate(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Color(0xFFE0D9D0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          foregroundColor: const Color(0xFF555555),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 13, color: Color(0xFFA32D2D)),
                            const SizedBox(width: 4),
                            Text(dateLabel),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        onPressed: () => _pickTime(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Color(0xFFE0D9D0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          foregroundColor: const Color(0xFF555555),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 13, color: Color(0xFFA32D2D)),
                            const SizedBox(width: 4),
                            Text(timeLabel),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Confirm send button
              SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed: () => _onConfirmSend(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  child: Text(s.ideaConfirmSend),
                ),
              ),
            ],
          ),
        ],
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
      activity: widget.idea.title(s.isNorwegian),
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
    final isNo = s.isNorwegian;
    final provider = context.watch<WeeklyIdeasProvider>();
    final isMyIdea = provider.sentIdea?.titleNo == widget.idea.titleNo;
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
    if (state == IdeaSendState.accepted && !_acceptedShown) {
      _acceptedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context, rootNavigator: true);
        final provRef = context.read<WeeklyIdeasProvider>();
        final ls = context.read<LanguageProvider>().s;
        final displayTitle = ls.ideaPartnerAcceptedTitle(
          widget.partnerName,
          widget.idea.title(ls.isNorwegian),
        );
        nav.push(RawDialogRoute<void>(
          pageBuilder: (ctx, anim, secAnim) => HeartConfirmDialog(
            displayTitle: displayTitle,
            date: provRef.acceptedPlanDate,
            s: ls,
          ),
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.35),
          barrierLabel: 'Dismiss',
          transitionDuration: Duration.zero,
        ));
        // Reset carousel state after overlay auto-dismisses.
        Future.delayed(const Duration(milliseconds: 2700), provRef.resetSendState);
      });
    }
    if (state == IdeaSendState.idle) {
      _declinedShown = false;
      _acceptedShown = false;
    }

    // If state moved away from idle while on the time page, snap back.
    if (state != IdeaSendState.idle && _onTimePage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _onTimePage) {
          _slideCtrl.reverse();
          setState(() => _onTimePage = false);
        }
      });
    }

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
            widget.idea.category(isNo),
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
        durationText = widget.idea.meta(isNo).split('·').first.trim();
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
      } else if (!widget.hasPartner) {
        button = GestureDetector(
          onTap: () {
            final ls = context.read<LanguageProvider>().s;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ls.soloSendDisabledHint),
              backgroundColor: AppTheme.textPrimary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              s.soloSendDisabledHint,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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

      final side1 = Container(
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
              child: GestureDetector(
                onLongPress: _isAdmin ? () => _pickAndUpload(context) : null,
                child: Opacity(
                  opacity: state == IdeaSendState.waiting ? 0.5 : 1.0,
                  child: ClipPath(
                    clipper: _CardDiagonalClipper(),
                    child: _imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            memCacheWidth: 600,
                            placeholder: _urlWasKnownAtInit
                                ? null
                                : (context, url) =>
                                    Container(color: AppTheme.white),
                            errorWidget: (context, url, error) =>
                                Container(color: AppTheme.white),
                          )
                        : Container(color: AppTheme.white),
                  ),
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
                    AutoSizeText(
                      widget.idea.title(isNo),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Georgia',
                        height: 1.2,
                      ),
                      minFontSize: 13,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (isPending)
                      AnimatedBuilder(
                        animation: _dotCtrl,
                        builder: (context, child) => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                durationText,
                                style: const TextStyle(
                                  color: AppTheme.textSubtle,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ...List.generate(3, (i) {
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
                                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFA32D2D),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      )
                    else
                      Text(
                        durationText,
                        style: const TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    button,
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      return ClipRect(
        child: Stack(
          children: [
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1, 0),
              ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeInOut)),
              child: side1,
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeInOut)),
              child: _buildTimeSide(context, s),
            ),
          ],
        ),
      );
    });
  }
}

// ─── Write-own compact waiting bar ───────────────────────────────────────────

class _WriteOwnWaitingBar extends StatelessWidget {
  final String coupleId;
  final String partnerName;

  const _WriteOwnWaitingBar({
    required this.coupleId,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA32D2D), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(
              s.homeWriteOwnWaiting(partnerName),
              style: const TextStyle(
                color: Color(0xFFA32D2D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const _BouncingDots(),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  context.read<WeeklyIdeasProvider>().cancelPendingIdea(coupleId),
              child: const Icon(Icons.close, color: Color(0xFFA32D2D), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Relationship duration counter ───────────────────────────────────────────

// ─── Next plan pill ────────────────────────────────────────────────────────────

class _NextPlanPill extends StatefulWidget {
  const _NextPlanPill();

  @override
  State<_NextPlanPill> createState() => _NextPlanPillState();
}

class _NextPlanPillState extends State<_NextPlanPill> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _nextActivity;
  DateTime? _nextDate;
  String _coupleId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coupleId = Provider.of<AppState>(context, listen: false).coupleId;
    if (coupleId != _coupleId && coupleId.isNotEmpty) {
      _coupleId = coupleId;
      _sub?.cancel();
      _sub = FirestoreService.weeklyPlanStream(coupleId).listen(_onSnap);
    }
  }

  void _onSnap(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 14));
    String? nearestActivity;
    DateTime? nearestDate;

    for (final doc in snap.docs) {
      final d = doc.data();
      final ts = d['date'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      if (dt.isBefore(now)) continue;
      if (dt.isAfter(cutoff)) continue;
      if (nearestDate == null || dt.isBefore(nearestDate)) {
        nearestDate = dt;
        nearestActivity = d['activity'] as String? ?? '';
      }
    }

    setState(() {
      _nextActivity = nearestActivity;
      _nextDate = nearestDate;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_nextActivity == null || _nextDate == null) return const SizedBox.shrink();
    final s = context.watch<LanguageProvider>().s;
    final text = s.homePlanPillFormat(_nextActivity!, _nextDate!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEAF0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFFA32D2D)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFA32D2D),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Relationship counter ──────────────────────────────────────────────────────

class _RelationshipCounterCard extends StatelessWidget {
  const _RelationshipCounterCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final since = context.watch<AppState>().togetherSince;

    if (since == null) return const SizedBox.shrink();

    final now = DateTime.now();
    int years = now.year - since.year;
    int months = now.month - since.month;
    int days = now.day - since.day;

    if (days < 0) {
      days += DateTime(now.year, now.month, 0).day;
      months--;
    }
    if (months < 0) { months += 12; years--; }

    const muted = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppTheme.textSubtle,
      height: 1.5,
    );
    const number = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Color(0xFFA32D2D),
      height: 1.5,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${s.homeCounterLabel} ', style: muted),
          TextSpan(text: '$years ', style: number),
          TextSpan(text: '${s.homeCounterYrs} ', style: muted),
          TextSpan(text: '$months ', style: number),
          TextSpan(text: '${s.homeCounterMos} ', style: muted),
          TextSpan(text: '$days ', style: number),
          TextSpan(text: s.homeCounterDays, style: muted),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─── Write-own bottom sheet ───────────────────────────────────────────────────

class _WriteOwnSheet extends StatefulWidget {
  const _WriteOwnSheet();

  @override
  State<_WriteOwnSheet> createState() => _WriteOwnSheetState();
}

class _WriteOwnSheetState extends State<_WriteOwnSheet> {
  final _ctrl = TextEditingController();
  DateTime? _proposedDate;
  TimeOfDay? _proposedTime;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final s = context.read<LanguageProvider>().s;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) {
        var displayMonth = DateTime(
          (_proposedDate ?? today).year,
          (_proposedDate ?? today).month,
          1,
        );
        var selected = _proposedDate ?? today;

        return StatefulBuilder(
          builder: (_, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: AppTheme.background,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CalendarCard(
                    displayMonth: displayMonth,
                    selectedDate: selected,
                    eventDates: const {},
                    s: s,
                    onPrevMonth: () => setDialogState(() {
                      displayMonth = DateTime(
                          displayMonth.year, displayMonth.month - 1, 1);
                    }),
                    onNextMonth: () => setDialogState(() {
                      displayMonth = DateTime(
                          displayMonth.year, displayMonth.month + 1, 1);
                    }),
                    onSelectDate: (date) {
                      setDialogState(() => selected = date);
                      setState(() => _proposedDate = date);
                      Navigator.pop(dialogCtx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _proposedTime != null
        ? DateTime(now.year, now.month, now.day,
            _proposedTime!.hour, _proposedTime!.minute)
        : DateTime(now.year, now.month, now.day, now.hour, now.minute);
    var selected = initial;
    final isNo = context.read<LanguageProvider>().isNorwegian;

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.background,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: initial,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isNo ? 'Ferdig' : 'Done',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() => _proposedTime =
          TimeOfDay(hour: selected.hour, minute: selected.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final dateLabel = _proposedDate != null
        ? '${_proposedDate!.day}.${_proposedDate!.month}'
        : s.ideaDatePlaceholder;
    final timeLabel = _proposedTime != null
        ? _proposedTime!.format(context)
        : s.ideaTimePlaceholder;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: 200,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
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
              const SizedBox(height: 16),
              Text(
                s.ideaWhenWorksForYou,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSubtle),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Color(0xFFE0D9D0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          foregroundColor: const Color(0xFF555555),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 14, color: Color(0xFFA32D2D)),
                            const SizedBox(width: 5),
                            Text(dateLabel),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Color(0xFFE0D9D0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          foregroundColor: const Color(0xFF555555),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 14, color: Color(0xFFA32D2D)),
                            const SizedBox(width: 5),
                            Text(timeLabel),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = _ctrl.text.trim();
                    if (text.isEmpty) return;
                    final appState = context.read<AppState>();
                    final provider = context.read<WeeklyIdeasProvider>();
                    final ls = context.read<LanguageProvider>().s;
                    if (provider.sendState == IdeaSendState.waiting) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        useRootNavigator: true,
                        builder: (ctx) => AlreadyPendingDialog(
                          pendingTitle:
                              provider.sentIdea?.title(ls.isNorwegian) ?? '',
                          s: ls,
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      final ok = await provider
                          .cancelForReplacement(appState.coupleId);
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ls.isNorwegian
                              ? 'Noe gikk galt – prøv igjen'
                              : 'Something went wrong – try again'),
                          backgroundColor: AppTheme.textPrimary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                        return;
                      }
                    }
                    DateTime? proposedAt;
                    if (_proposedDate != null) {
                      final d = _proposedDate!;
                      final t =
                          _proposedTime ?? const TimeOfDay(hour: 20, minute: 0);
                      proposedAt =
                          DateTime(d.year, d.month, d.day, t.hour, t.minute);
                    }
                    provider.sendIdea(
                      WeeklyIdea(
                        titleNo: text,
                        titleEn: text,
                        categoryNo: '',
                        categoryEn: '',
                        metaNo: '',
                        metaEn: '',
                        descriptionNo: text,
                        descriptionEn: text,
                        cardColor: Colors.white,
                        tagColor: const Color(0xFFFCF0EC),
                        tagTextColor: const Color(0xFFA32D2D),
                        icon: Icons.edit_outlined,
                        buttonColor: const Color(0xFFA32D2D),
                      ),
                      appState.coupleId,
                      appState.userId,
                      appState.displayName,
                      partnerId: appState.partnerId,
                      coverImageUrl: null,
                      proposedAt: proposedAt,
                    );
                    if (context.mounted) Navigator.pop(context);
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
    );
  }
}

// ─── Bouncing dots indicator ─────────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final start = i / 3.0;
          final end = (i + 1) / 3.0;
          final v = _ctrl.value;
          final t = (v >= start && v < end)
              ? (v - start) / (end - start)
              : 0.0;
          final dy = -sin(t * pi) * 5.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 5,
              height: 5,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: const BoxDecoration(
                color: Color(0xFFA32D2D),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
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

// ── _SoloPreviewGrid ───────────────────────────────────────────────────────────

class _SoloPreviewGrid extends StatelessWidget {
  final AppStrings s;
  const _SoloPreviewGrid({required this.s});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PreviewCardData(
        title: s.soloPreviewIdeasTitle,
        subtitle: s.soloPreviewIdeasSub,
        icon: Icons.favorite_rounded,
        bg: const Color(0xFFFBEAF0),
        iconColor: const Color(0xFFA32D2D),
      ),
      _PreviewCardData(
        title: s.soloPreviewPlanTitle,
        subtitle: s.soloPreviewPlanSub,
        icon: Icons.calendar_today_rounded,
        bg: const Color(0xFFEAF3DE),
        iconColor: const Color(0xFF27500A),
      ),
      _PreviewCardData(
        title: s.soloPreviewMemoriesTitle,
        subtitle: s.soloPreviewMemoriesSub,
        icon: Icons.photo_library_rounded,
        bg: const Color(0xFFE6F1FB),
        iconColor: const Color(0xFF185FA5),
      ),
      _PreviewCardData(
        title: s.soloPreviewStreakTitle,
        subtitle: s.soloPreviewStreakSub,
        icon: Icons.local_fire_department_rounded,
        bg: const Color(0xFFFAEEDA),
        iconColor: const Color(0xFFBA7517),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.soloPreviewSection,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: cards.map((data) => _PreviewCard(data: data)).toList(),
        ),
      ],
    );
  }
}

class _PreviewCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final Color iconColor;
  const _PreviewCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.iconColor,
  });
}

class _PreviewCard extends StatelessWidget {
  final _PreviewCardData data;
  const _PreviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: data.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: data.iconColor, size: 26),
              const SizedBox(height: 8),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
