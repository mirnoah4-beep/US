import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';

// ── Data types ─────────────────────────────────────────────────────────────────

enum _Phase { none, invited, connected }

class _AvatarColor {
  final Color bg;
  final Color fg;
  final Color border;
  const _AvatarColor(this.bg, this.fg, this.border);
}

const _kColors = [
  _AvatarColor(Color(0xFFFAECE7), Color(0xFF993C1D), Color(0xFF993C1D)), // coral
  _AvatarColor(Color(0xFFEAF3DE), Color(0xFF3B6D11), Color(0xFF3B6D11)), // green
  _AvatarColor(Color(0xFFFAEEDA), Color(0xFF854F0B), Color(0xFF854F0B)), // amber
  _AvatarColor(Color(0xFFEEEDFE), Color(0xFF534AB7), Color(0xFF534AB7)), // purple
];

class _Milestone {
  final int years;
  final DateTime date;
  final int daysAway;
  const _Milestone(this.years, this.date, this.daysAway);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class CoupleSetupScreen extends StatefulWidget {
  const CoupleSetupScreen({super.key});

  @override
  State<CoupleSetupScreen> createState() => _CoupleSetupScreenState();
}

class _CoupleSetupScreenState extends State<CoupleSetupScreen>
    with TickerProviderStateMixin {

  // ── Own profile ──────────────────────────────────────────────────────
  String _name = 'Noah';
  late final TextEditingController _nameCtrl;
  bool _nameChanged = false;
  int _colorIdx = 0;
  XFile? _avatar;

  // ── Partner ──────────────────────────────────────────────────────────
  _Phase _phase = _Phase.none;
  final _inviteCtrl = TextEditingController();
  String _partnerName = 'Sarah';
  int _partnerColorIdx = 1;
  XFile? _partnerAvatar;
  DateTime? _togetherSince;

  // ── Animation ─────────────────────────────────────────────────────────
  bool _showConnectAnim = false;
  late final AnimationController _travelCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _connectCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _heartAnim;
  late final ConfettiController _confettiCtrl;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: _name)
      ..addListener(_onNameChange);

    _travelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _connectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _slideAnim = CurvedAnimation(
      parent: _connectCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _heartAnim = CurvedAnimation(
      parent: _connectCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
    );

    _confettiCtrl =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onNameChange)
      ..dispose();
    _inviteCtrl.dispose();
    _travelCtrl.dispose();
    _pulseCtrl.dispose();
    _connectCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ── Callbacks ─────────────────────────────────────────────────────────

  void _onNameChange() {
    setState(() => _nameChanged = _nameCtrl.text.trim() != _name);
  }

  void _saveName() {
    FocusScope.of(context).unfocus();
    setState(() {
      _name = _nameCtrl.text.trim();
      _nameChanged = false;
    });
    // TODO: Firestore /users/{userId}/name = _name
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final file = await _picker.pickImage(
        source: source, maxWidth: 400, maxHeight: 400, imageQuality: 85);
    if (file != null && mounted) {
      setState(() => _avatar = file);
      // TODO: Upload to Firebase Storage /users/{userId}/avatar.jpg
      // TODO: Update Firestore /users/{userId}/avatarUrl
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarOptionsSheet(
        hasPhoto: _avatar != null,
        onCamera: () {
          Navigator.pop(context);
          _pickAvatar(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(context);
          _pickAvatar(ImageSource.gallery);
        },
        onRemove: _avatar != null
            ? () {
                Navigator.pop(context);
                setState(() => _avatar = null);
              }
            : null,
      ),
    );
  }

  void _sendInvite() {
    if (_inviteCtrl.text.trim().isEmpty) return;
    // TODO: Firestore create /invites/{code}, set status="pending"
    setState(() => _phase = _Phase.invited);
  }

  void _shareInviteLink() {
    // TODO: Share.share('Join me on Us — https://us-app.com/invite/...')
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sharing invite link…'),
        backgroundColor: AppTheme.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Long-press State B card → simulate partner accepted (dev shortcut)
  Future<void> _simulatePartnerAccepted() async {
    // TODO: In production, triggered by Firestore listener on /invites/{code}
    setState(() {
      _partnerName = 'Sarah';
      _partnerColorIdx = 1;
      _showConnectAnim = true;
    });
    _confettiCtrl.play();
    await _connectCtrl.forward();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _showConnectAnim = false;
      _phase = _Phase.connected;
      _togetherSince ??= DateTime(2022, 3, 15);
    });
  }

  Future<void> _changeTogetherSince() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _togetherSince ?? DateTime(2022, 3, 15),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC1544A),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF2C2420),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      setState(() => _togetherSince = date);
      // TODO: Firestore /couples/{coupleId}/togetherSince
    }
  }

  Future<void> _confirmRemovePartner() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove $_partnerName?',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2420),
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'This will disconnect both accounts. You can reconnect later.',
          style: TextStyle(fontSize: 14, color: Color(0xFF8C7B72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8C7B72))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(
                    color: Color(0xFFA32D2D),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      // TODO: Delete /couples/{coupleId}, reset both users
      _connectCtrl.reset();
      setState(() {
        _phase = _Phase.none;
        _togetherSince = null;
        _inviteCtrl.clear();
      });
    }
  }

  _Milestone? _upcomingMilestone() {
    if (_togetherSince == null) return null;
    final now = DateTime.now();
    for (var y = 1; y <= 50; y++) {
      final ann = DateTime(
          _togetherSince!.year + y,
          _togetherSince!.month,
          _togetherSince!.day);
      if (ann.isAfter(now)) {
        final daysAway = ann.difference(now).inDays;
        return daysAway <= 60 ? _Milestone(y, ann, daysAway) : null;
      }
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final milestone = _phase == _Phase.connected ? _upcomingMilestone() : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
              children: [
                _buildTopBar(s),
                const SizedBox(height: 28),
                _sectionLabel(s.coupleYourProfile),
                const SizedBox(height: 8),
                _buildProfileCard(s),
                const SizedBox(height: 24),
                _sectionLabel(s.coupleYourPartner),
                const SizedBox(height: 8),
                _buildPartnerSection(s),
                if (_phase == _Phase.connected) ...[
                  const SizedBox(height: 24),
                  _sectionLabel(s.coupleTogetherSince.toUpperCase()),
                  const SizedBox(height: 8),
                  _buildTogetherSinceCard(s),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  if (milestone != null) ...[
                    const SizedBox(height: 16),
                    _buildMilestoneCard(s, milestone),
                  ],
                  const SizedBox(height: 24),
                  _sectionLabel('DANGER ZONE'),
                  const SizedBox(height: 8),
                  _buildDangerZone(),
                ],
              ],
            ),
            // Confetti burst on connection
            ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              gravity: 0.3,
              colors: const [
                Color(0xFFC1544A),
                Color(0xFFEAF3DE),
                Color(0xFFFAEEDA),
                Color(0xFFF5C4B3),
                Color(0xFF3B6D11),
                Color(0xFFFAC775),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────

  Widget _buildTopBar(s) {
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
              border: Border.all(
                  color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: const Center(
              child: Icon(Icons.arrow_back_ios_new,
                  size: 16, color: Color(0xFF888888)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          s.coupleSetupTitle,
          style: const TextStyle(
            color: Color(0xFF2C2420),
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFFB4B2A9),
        letterSpacing: 0.77,
      ),
    );
  }

  // ── Profile card ───────────────────────────────────────────────────────

  Widget _buildProfileCard(s) {
    final color = _kColors[_colorIdx];
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : '?';

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + edit badge
          GestureDetector(
            onTap: _showAvatarOptions,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                children: [
                  _avatarCircle(
                      size: 64,
                      file: _avatar,
                      initial: initial,
                      color: color),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC1544A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + hint
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onFieldSubmitted: (_) {
                    if (_nameChanged) _saveName();
                  },
                ),
                const SizedBox(height: 3),
                const Text(
                  'Tap avatar to change colour or add photo',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFFB4B2A9)),
                ),
                if (_nameChanged) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: FilledButton(
                      onPressed: _saveName,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC1544A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(s.coupleSave,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Color swatches (4 circles)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_kColors.length, (i) {
                final c = _kColors[i];
                final sel = i == _colorIdx;
                return GestureDetector(
                  onTap: () => setState(() => _colorIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel
                            ? c.border
                            : Colors.transparent,
                        width: sel ? 2.0 : 0,
                      ),
                    ),
                    child: sel
                        ? Center(
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: c.fg,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Partner section dispatcher ──────────────────────────────────────────

  Widget _buildPartnerSection(AppStrings s) {
    if (_showConnectAnim) return _buildConnectionAnim();
    return switch (_phase) {
      _Phase.none => _buildStateA(s),
      _Phase.invited => _buildStateB(s),
      _Phase.connected => _buildStateC(s),
    };
  }

  // ── State A — no partner ───────────────────────────────────────────────

  Widget _buildStateA(AppStrings s) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.alternate_email,
                    size: 20, color: Color(0xFFB4B2A9)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inviteCtrl,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF1A1A1A)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Phone, email or Us ID',
                      hintStyle: TextStyle(
                          color: Color(0xFFB4B2A9), fontSize: 15),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your partner needs to have the Us app installed',
            style: TextStyle(
                fontSize: 12, color: Color(0xFFB4B2A9)),
          ),
          const SizedBox(height: 16),
          const Divider(
              height: 1, thickness: 0.5, color: Color(0xFFF1EFE8)),
          const SizedBox(height: 16),
          // Send invite
          SizedBox(
            width: double.infinity,
            child: Builder(builder: (_) {
              final enabled = _inviteCtrl.text.trim().isNotEmpty;
              return FilledButton.icon(
                onPressed: enabled ? _sendInvite : null,
                icon: const Icon(Icons.send, size: 18),
                label: Text(
                  s.coupleInviteButton,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: enabled
                      ? const Color(0xFFC1544A)
                      : const Color(0xFFF1EFE8),
                  foregroundColor: enabled
                      ? Colors.white
                      : const Color(0xFFB4B2A9),
                  disabledBackgroundColor:
                      const Color(0xFFF1EFE8),
                  disabledForegroundColor:
                      const Color(0xFFB4B2A9),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // "or" divider
          Row(
            children: [
              const Expanded(
                  child: Divider(
                      thickness: 0.5, color: Color(0xFFF1EFE8))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                child: const Text('or',
                    style: TextStyle(
                        color: Color(0xFFB4B2A9),
                        fontSize: 13)),
              ),
              const Expanded(
                  child: Divider(
                      thickness: 0.5, color: Color(0xFFF1EFE8))),
            ],
          ),
          const SizedBox(height: 12),
          // Share invite link
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareInviteLink,
              icon: const Icon(Icons.share,
                  size: 18, color: Color(0xFF5F5E5A)),
              label: Text(
                s.coupleShareLink,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5F5E5A)),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF1EFE8),
                side: BorderSide.none,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── State B — invite sent ──────────────────────────────────────────────

  Widget _buildStateB(AppStrings s) {
    final ownInitial =
        _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final ownColor = _kColors[_colorIdx];

    return GestureDetector(
      onLongPress: _simulatePartnerAccepted,
      child: _Card(
        child: Column(
          children: [
            // Canvas animation
            SizedBox(
              height: 160,
              child: AnimatedBuilder(
                animation:
                    Listenable.merge([_travelCtrl, _pulse]),
                builder: (_, __) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20),
                    child: Row(
                      children: [
                        // Own avatar (pulsing)
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Transform.scale(
                              scale: _pulse.value,
                              child: _avatarCircle(
                                size: 64,
                                file: _avatar,
                                initial: ownInitial,
                                color: ownColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFC1544A))),
                          ],
                        ),
                        // Traveling dot line
                        Expanded(
                          child: CustomPaint(
                            painter: _LinePainter(
                                t: _travelCtrl.value),
                          ),
                        ),
                        // Partner dashed circle
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            _DashedCircle(
                              size: 64,
                              child: const Center(
                                child: Text('?',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight:
                                            FontWeight.w500,
                                        color: Color(
                                            0xFFB4B2A9))),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Partner?',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFB4B2A9))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Waiting for your partner…',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Invite sent — they\'ll appear here when they join',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            // Pending badge with pulsing dot
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => _PendingBadge(
                  pulseT: _pulseCtrl.value),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _shareInviteLink,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC1544A),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(s.coupleResendInvite,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                const Text(' · ',
                    style: TextStyle(
                        color: Color(0xFFB4B2A9))),
                TextButton(
                  onPressed: () => setState(() {
                    _phase = _Phase.none;
                    _inviteCtrl.clear();
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB4B2A9),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(s.coupleCancelInvite,
                      style:
                          const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── State C — connected ────────────────────────────────────────────────

  Widget _buildStateC(AppStrings s) {
    final ownInitial =
        _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final ownColor = _kColors[_colorIdx];
    final partnerInitial = _partnerName.isNotEmpty
        ? _partnerName[0].toUpperCase()
        : 'P';
    final partnerColor = _kColors[_partnerColorIdx];

    return _Card(
      child: Column(
        children: [
          // Avatar pair
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  _avatarCircle(
                    size: 64,
                    file: _avatar,
                    initial: ownInitial,
                    color: ownColor,
                    borderColor: const Color(0xFF993C1D),
                  ),
                  const SizedBox(height: 6),
                  Text(_name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF993C1D))),
                ],
              ),
              const Padding(
                padding:
                    EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Icon(Icons.favorite,
                    size: 22, color: Color(0xFFC1544A)),
              ),
              Column(
                children: [
                  _avatarCircle(
                    size: 64,
                    file: _partnerAvatar,
                    initial: partnerInitial,
                    color: partnerColor,
                    borderColor: const Color(0xFF3B6D11),
                  ),
                  const SizedBox(height: 6),
                  Text(_partnerName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3B6D11))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Connection animation (B → C) ───────────────────────────────────────

  Widget _buildConnectionAnim() {
    final ownInitial =
        _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final ownColor = _kColors[_colorIdx];
    final partnerInitial = _partnerName.isNotEmpty
        ? _partnerName[0].toUpperCase()
        : 'P';
    final partnerColor = _kColors[_partnerColorIdx];

    return _Card(
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _connectCtrl,
              builder: (_, __) {
                final slide = _slideAnim.value;
                final heartScale = _heartAnim.value;
                return LayoutBuilder(
                  builder: (_, constraints) {
                    final w = constraints.maxWidth;
                    final leftX = slide * (w * 0.18);
                    final rightX = (w - 64) -
                        slide * (w * 0.18);
                    return Stack(
                      children: [
                        Positioned(
                          left: leftX,
                          top: 20,
                          child: _avatarCircle(
                            size: 64,
                            file: _avatar,
                            initial: ownInitial,
                            color: ownColor,
                          ),
                        ),
                        Positioned(
                          left: rightX,
                          top: 20,
                          child: _avatarCircle(
                            size: 64,
                            file: _partnerAvatar,
                            initial: partnerInitial,
                            color: partnerColor,
                          ),
                        ),
                        if (heartScale > 0)
                          Positioned(
                            left: w / 2 - 11,
                            top: 4,
                            child: Transform.scale(
                              scale: heartScale,
                              child: const Icon(
                                  Icons.favorite,
                                  color:
                                      Color(0xFFC1544A),
                                  size: 22),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You\'re connected!',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B6D11)),
          ),
          const SizedBox(height: 4),
          Text(
            '$_partnerName joined Us',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3DE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF3B6D11)
                      .withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14, color: Color(0xFF3B6D11)),
                SizedBox(width: 6),
                Text('Connected',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B6D11))),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Together since card ────────────────────────────────────────────────

  Widget _buildTogetherSinceCard(AppStrings s) {
    final since = _togetherSince;
    final days = since != null
        ? max(0, DateTime.now().difference(since).inDays)
        : 0;
    final dateLabel = since != null
        ? DateFormat('MMMM yyyy').format(since)
        : s.coupleSetDatePlaceholder;

    return _Card(
      child: Row(
        children: [
          const Icon(Icons.favorite,
              size: 16, color: Color(0xFFC1544A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Together since $dateLabel',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C2420),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.coupleDaysTogether(days),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _changeTogetherSince,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC1544A),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              tapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(s.coupleChangeDate,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    // TODO: fetch real counts from AppState / Firestore
    return Row(
      children: const [
        Expanded(
          child: _StatCard(
            bg: Color(0xFFFAEEDA),
            border: Color(0xFFFAC775),
            icon: Icons.calendar_today_rounded,
            iconColor: Color(0xFF854F0B),
            value: '4',
            label: 'moments this month',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            bg: Color(0xFFEAF3DE),
            border: Color(0xFF3B6D11),
            icon: Icons.local_fire_department_rounded,
            iconColor: Color(0xFF3B6D11),
            value: '3',
            label: 'weeks in a row',
          ),
        ),
      ],
    );
  }

  // ── Milestone card ─────────────────────────────────────────────────────

  Widget _buildMilestoneCard(AppStrings s, _Milestone m) {
    final dateLabel = DateFormat('MMMM yyyy').format(m.date);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFAC775), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_outlined,
              size: 20, color: Color(0xFF854F0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.coupleYearsLabel(m.years),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2420),
                  ),
                ),
                Text(
                  '$dateLabel · ${m.daysAway} days away',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF854F0B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Danger zone ────────────────────────────────────────────────────────

  Widget _buildDangerZone() {
    return _Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 4, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person_remove_outlined,
              size: 18, color: Color(0xFFA32D2D)),
        ),
        title: Text(
          'Remove $_partnerName as partner',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA32D2D),
          ),
        ),
        subtitle: const Text(
          'This will disconnect both accounts',
          style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
        trailing: const Icon(Icons.chevron_right,
            size: 18, color: Color(0xFFD3D1C7)),
        onTap: _confirmRemovePartner,
      ),
    );
  }

  // ── Avatar circle helper ───────────────────────────────────────────────

  Widget _avatarCircle({
    required double size,
    XFile? file,
    required String initial,
    required _AvatarColor color,
    Color? borderColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.bg,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: file != null
          ? ClipOval(
              child: Image.file(
                File(file.path),
                fit: BoxFit.cover,
                width: size,
                height: size,
              ),
            )
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: color.fg,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFE0D9D0), width: 0.5),
      ),
      child: child,
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final double pulseT;
  const _PendingBadge({required this.pulseT});

  @override
  Widget build(BuildContext context) {
    final dotColor = Color.lerp(
      const Color(0xFFC1544A),
      const Color(0xFFFAC775),
      pulseT,
    )!;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFAC775)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF854F0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color bg;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: border.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: iconColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarOptionsSheet extends StatelessWidget {
  final bool hasPhoto;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;

  const _AvatarOptionsSheet({
    required this.hasPhoto,
    required this.onCamera,
    required this.onGallery,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionTile(
            icon: Icons.camera_alt_outlined,
            label: 'Take photo',
            onTap: onCamera,
          ),
          _OptionTile(
            icon: Icons.photo_library_outlined,
            label: 'Choose from library',
            onTap: onGallery,
          ),
          if (hasPhoto && onRemove != null)
            _OptionTile(
              icon: Icons.delete_outline,
              label: 'Remove photo',
              color: const Color(0xFFA32D2D),
              onTap: onRemove!,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF2C2420),
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title:
          Text(label, style: TextStyle(color: color, fontSize: 15)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _DashedCircle extends StatelessWidget {
  final double size;
  final Widget child;

  const _DashedCircle({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedCirclePainter(),
      child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child)),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD3D1C7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 0.75;
    const count = 14;
    const dashAngle = (pi * 2 / count) * 0.55;
    const gapAngle = (pi * 2 / count) - dashAngle;

    var angle = -pi / 2.0;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dashAngle,
        false,
        paint,
      );
      angle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// Draws a dashed horizontal line with a traveling coral dot
class _LinePainter extends CustomPainter {
  final double t; // 0.0 → 1.0, from AnimationController.repeat()
  const _LinePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const dashLen = 5.0;
    const gapLen = 4.0;

    final dashPaint = Paint()
      ..color = const Color(0xFFF5C4B3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(min(x + dashLen, size.width), y),
        dashPaint,
      );
      x += dashLen + gapLen;
    }

    // Ping-pong the dot: 0→1→0
    final pingPong = (sin(t * 2 * pi) + 1) / 2;
    final dotX = pingPong * size.width;

    canvas.drawCircle(
      Offset(dotX, y),
      5.0,
      Paint()..color = const Color(0xFFC1544A),
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.t != t;
}
