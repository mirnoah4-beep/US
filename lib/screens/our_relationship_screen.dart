import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class OurRelationshipScreen extends StatefulWidget {
  const OurRelationshipScreen({super.key});

  @override
  State<OurRelationshipScreen> createState() => _OurRelationshipScreenState();
}

class _OurRelationshipScreenState extends State<OurRelationshipScreen> {
  // Duration computed once per unique since-date (not live-ticking)
  int _years = 0, _months = 0, _days = 0, _secs = 0;
  DateTime? _computedFor;

  void _computeDuration(DateTime since) {
    if (since == _computedFor) return;
    _computedFor = since;
    final now = DateTime.now();
    int y = now.year - since.year;
    int m = now.month - since.month;
    int d = now.day - since.day;
    if (d < 0) {
      m--;
      d += DateTime(now.year, now.month, 0).day;
    }
    if (m < 0) {
      y--;
      m += 12;
    }
    _years = y;
    _months = m;
    _days = d;
    _secs = now.second;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final appState = context.watch<AppState>();

    final since = appState.togetherSince;
    if (since != null) _computeDuration(since);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            _buildHeader(context, s),
            const SizedBox(height: 40),
            _buildAvatarSection(appState, s),
            const SizedBox(height: 32),
            _buildAnniversaryCard(context, appState, s),
            const SizedBox(height: 12),
            _buildDisconnectCard(context, s, appState),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppStrings s) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: AppTheme.textSubtle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          s.ourRelationshipTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }

  // ── Avatars + names ────────────────────────────────────────────────────────

  Widget _buildAvatarSection(AppState appState, AppStrings s) {
    final displayName = appState.displayName;
    final partnerName = appState.partnerName;
    final userInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : null;
    final partnerInitial = partnerName.isNotEmpty ? partnerName[0].toUpperCase() : null;
    final String nameText;
    if (displayName.isNotEmpty && partnerName.isNotEmpty) {
      nameText = '$displayName & $partnerName';
    } else {
      nameText = displayName.isNotEmpty ? displayName : partnerName;
    }

    const avSize = 76.0;
    const overlap = 14.0;
    const heartSize = 24.0;
    const stackW = avSize * 2 - overlap;

    return Column(
      children: [
        SizedBox(
          width: stackW,
          height: avSize + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // User avatar (left, slightly behind)
              Positioned(
                left: 0,
                top: 4,
                child: _buildAvatar(
                  imageUrl: appState.userAvatarUrl,
                  initial: userInitial,
                  bgColor: const Color(0xFFFAECE7),
                  iconColor: AppTheme.accentRose,
                ),
              ),
              // Partner avatar (right, on top)
              Positioned(
                right: 0,
                top: 4,
                child: _buildAvatar(
                  imageUrl: appState.partnerAvatarUrl,
                  initial: partnerInitial,
                  bgColor: const Color(0xFFFAEEDA),
                  iconColor: const Color(0xFF854F0B),
                ),
              ),
              // Heart badge centered at overlap
              Positioned(
                left: (stackW - heartSize) / 2,
                top: (avSize - heartSize) / 2 + 4,
                child: Container(
                  width: heartSize,
                  height: heartSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 13,
                    color: AppTheme.accentRose,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          nameText.isEmpty ? '—' : nameText,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({
    required String? imageUrl,
    required String? initial,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 76,
                height: 76,
                placeholder: (_, _) => _avatarFallback(initial, iconColor),
                errorWidget: (_, _, _) => _avatarFallback(initial, iconColor),
              )
            : _avatarFallback(initial, iconColor),
      ),
    );
  }

  Widget _avatarFallback(String? initial, Color color) {
    if (initial != null) {
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }
    return Icon(Icons.person, size: 36, color: color);
  }

  // ── Anniversary card ───────────────────────────────────────────────────────

  Widget _buildAnniversaryCard(
    BuildContext context,
    AppState appState,
    AppStrings s,
  ) {
    final since = appState.togetherSince;
    final hasRealDate = since != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Date label ─────────────────────────────────────────────────
          Text(
            hasRealDate
                ? s.settingsTogetherSince(s.ourRelationshipFullDate(since))
                : s.ourRelationshipNoDate,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: hasRealDate ? AppTheme.textSecondary : AppTheme.textMuted,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 18),
          // ── Timer row ──────────────────────────────────────────────────
          _buildTimerRow(s),
          const SizedBox(height: 20),
          // ── Action button ──────────────────────────────────────────────
          _buildDateButton(context, s, appState),
        ],
      ),
    );
  }

  Widget _buildTimerRow(AppStrings s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timerUnit(_years.toString(), s.ourRelationshipYears),
        _timerColon(),
        _timerUnit(_months.toString().padLeft(2, '0'), s.ourRelationshipMonths),
        _timerColon(),
        _timerUnit(_days.toString().padLeft(2, '0'), s.ourRelationshipDays),
        _timerColon(),
        _timerUnit(_secs.toString().padLeft(2, '0'), s.ourRelationshipSecs),
      ],
    );
  }

  Widget _timerUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _timerColon() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 18),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          color: Color(0xFFD3D1C7),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildDateButton(BuildContext context, AppStrings s, AppState appState) {
    final hasRealDate = appState.togetherSince != null;
    return SizedBox(
      width: double.infinity,
      child: hasRealDate
          ? OutlinedButton.icon(
              onPressed: () => _pickDate(context, appState),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: Color(0xFFE0D9D0), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                s.ourRelationshipChangeDate,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            )
          : FilledButton.icon(
              onPressed: () => _pickDate(context, appState),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                s.ourRelationshipProposeDate,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Future<void> _pickDate(BuildContext context, AppState appState) async {
    final initial = appState.togetherSince ??
        DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !context.mounted) return;
    final coupleId = context.read<AppState>().coupleId;
    if (coupleId.isEmpty) return;
    try {
      await FirestoreService.setTogetherSince(coupleId, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Disconnect card ────────────────────────────────────────────────────────

  Widget _buildDisconnectCard(
      BuildContext context, AppStrings s, AppState appState) {
    final requested = appState.disconnectRequestedBy;
    final myId = appState.userId;
    final partnerId = appState.partnerId;
    final partnerName =
        appState.partnerName.isNotEmpty ? appState.partnerName : '?';

    Widget cardChild;

    if (requested == myId) {
      // ── I requested: show waiting state ──────────────────────────────────
      cardChild = Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFF856404),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.ourRelationshipWaitingFor(partnerName),
                    style: const TextStyle(
                      color: Color(0xFF856404),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    _cancelDisconnectRequest(context, appState.coupleId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5F5E5A),
                  side: const BorderSide(color: Color(0xFFE0D9D0)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  s.ourRelationshipCancelRequest,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (requested == partnerId && partnerId.isNotEmpty) {
      // ── Partner requested: show approval banner ───────────────────────────
      cardChild = Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.link_off,
                    color: Color(0xFFA32D2D),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.ourRelationshipDisconnectRequestedBy(partnerName),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        _approveDisconnect(context, s, appState),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA32D2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      s.ourRelationshipDisconnectApprove,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _cancelDisconnectRequest(context, appState.coupleId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5F5E5A),
                      side: const BorderSide(color: Color(0xFFE0D9D0)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      s.ourRelationshipDeclineRequest,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // ── No request: show disconnect button ────────────────────────────────
      cardChild = ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.link_off,
            color: Color(0xFFA32D2D),
            size: 20,
          ),
        ),
        title: Text(
          s.settingsDisconnect,
          style: const TextStyle(
            color: Color(0xFFA32D2D),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => _requestDisconnect(context, s, partnerName, appState),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: cardChild,
    );
  }

  // ── Confirm and send request ───────────────────────────────────────────────

  Future<void> _requestDisconnect(BuildContext context, AppStrings s,
      String partnerName, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFAF7F4),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.link_off,
                  color: Color(0xFFA32D2D),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.settingsDisconnectTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.settingsDisconnectBody(partnerName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888780),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    s.settingsDisconnectConfirm,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5F5E5A),
                    side: const BorderSide(color: Color(0xFFE0D9D0)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    s.settingsDisconnectCancel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final coupleId = appState.coupleId;
    final userId = appState.userId;
    if (coupleId.isEmpty) return;

    try {
      await FirestoreService.requestDisconnect(coupleId, userId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Partner approved — execute disconnect ─────────────────────────────────

  Future<void> _approveDisconnect(
      BuildContext context, AppStrings s, AppState appState) async {
    final coupleId = appState.coupleId;
    final partnerId = appState.partnerId;
    if (coupleId.isEmpty) return;
    try {
      await FirestoreService.disconnectCouple(
        coupleId: coupleId,
        currentUserId: appState.userId,
        partnerId: partnerId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Cancel / decline request ──────────────────────────────────────────────

  Future<void> _cancelDisconnectRequest(
      BuildContext context, String coupleId) async {
    if (coupleId.isEmpty) return;
    try {
      await FirestoreService.clearDisconnectRequest(coupleId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
