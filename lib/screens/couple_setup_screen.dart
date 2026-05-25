import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

enum _PartnerState { none, invited, connected }

class _AvatarColor {
  final Color bg;
  final Color fg;
  const _AvatarColor(this.bg, this.fg);
}

const _kAvatarColors = [
  _AvatarColor(Color(0xFFFAECE7), Color(0xFF993C1D)), // coral
  _AvatarColor(Color(0xFFEAF3DE), Color(0xFF3B6D11)), // green
  _AvatarColor(Color(0xFFFAEEDA), Color(0xFF854F0B)), // amber
  _AvatarColor(Color(0xFFE1F5EE), Color(0xFF0F6E56)), // teal
  _AvatarColor(Color(0xFFFBEAF0), Color(0xFF993556)), // pink
  _AvatarColor(Color(0xFFEEEDFE), Color(0xFF534AB7)), // purple
];

const _kColorLabels = ['Coral', 'Green', 'Amber', 'Teal', 'Pink', 'Purple'];

class _Milestone {
  final int years;
  final DateTime date;
  const _Milestone(this.years, this.date);
}

class CoupleSetupScreen extends StatefulWidget {
  const CoupleSetupScreen({super.key});

  @override
  State<CoupleSetupScreen> createState() => _CoupleSetupScreenState();
}

class _CoupleSetupScreenState extends State<CoupleSetupScreen>
    with TickerProviderStateMixin {

  // ── Profile ─────────────────────────────────────────────────────────
  String _savedName = 'Noah';
  late final TextEditingController _nameCtrl;
  bool _nameChanged = false;
  int _colorIdx = 0;

  // ── Partner ──────────────────────────────────────────────────────────
  _PartnerState _partnerState = _PartnerState.none;
  String _partnerName = 'Alex';
  int _partnerColorIdx = 1;
  DateTime? _togetherSince;
  String _inviteCode = '';

  // ── Animations ───────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _dotsCtrl;
  late AnimationController _successCtrl;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: _savedName)
      ..addListener(_onNameChange);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.16).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onNameChange)
      ..dispose();
    _pulseCtrl.dispose();
    _dotsCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  void _onNameChange() {
    setState(() => _nameChanged = _nameCtrl.text.trim() != _savedName);
  }

  void _saveName() {
    FocusScope.of(context).unfocus();
    setState(() {
      _savedName = _nameCtrl.text.trim();
      _nameChanged = false;
    });
    // Firestore: /users/{userId}/name = _savedName
  }

  void _sendInvite() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(36)]).join();
    setState(() {
      _inviteCode = code;
      _partnerState = _PartnerState.invited;
    });
    // Firestore: create /invites/{code}
    _openShareSheet(code);
  }

  void _openShareSheet(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(link: 'https://us-app.com/invite/$code'),
    );
  }

  void _cancelInvite() {
    // Firestore: delete /invites/{_inviteCode}
    setState(() {
      _inviteCode = '';
      _partnerState = _PartnerState.none;
    });
  }

  // Long-press State B card to simulate partner accepting (dev only)
  void _simulatePartnerAccepted() {
    setState(() {
      _partnerName = 'Alex';       // would come from Firestore in production
      _partnerColorIdx = 1;        // would come from Firestore in production
      _togetherSince = DateTime.now();
      _partnerState = _PartnerState.connected;
      _showSuccess = true;
    });
    // Firestore: create /couples/{id}, delete /invites/{code}
    _successCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showSuccess = false);
    });
  }

  Future<void> _confirmRemovePartner() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove $_partnerName as your partner?',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2420),
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'This will disconnect both accounts.',
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
            child: const Text(
              'Remove',
              style: TextStyle(
                  color: Color(0xFFA32D2D), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      // Firestore: delete couple doc, reset both users
      setState(() {
        _togetherSince = null;
        _partnerState = _PartnerState.none;
      });
    }
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
      // Firestore: /couples/{coupleId}/togetherSince = date
    }
  }

  _Milestone? _upcomingMilestone() {
    if (_togetherSince == null) return null;
    final now = DateTime.now();
    for (var y = 1; y <= 50; y++) {
      final ann = DateTime(
        _togetherSince!.year + y,
        _togetherSince!.month,
        _togetherSince!.day,
      );
      if (ann.isAfter(now)) {
        final days = ann.difference(now).inDays;
        return days <= 30 ? _Milestone(y, ann) : null;
      }
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
              children: [
                _buildTopBar(),
                const SizedBox(height: 28),
                _sectionLabel('Your profile'),
                const SizedBox(height: 8),
                _buildProfileCard(),
                const SizedBox(height: 24),
                _sectionLabel('Your partner'),
                const SizedBox(height: 8),
                _buildPartnerCard(),
                if (_partnerState == _PartnerState.connected) ...[
                  const SizedBox(height: 24),
                  _sectionLabel('Together since'),
                  const SizedBox(height: 8),
                  _buildTogetherSinceCard(),
                ],
              ],
            ),
            if (_showSuccess) _buildSuccessOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
              child: Icon(Icons.arrow_back_ios_new,
                  size: 15, color: Color(0xFF888888)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Couple setup',
          style: TextStyle(
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

  Widget _card({
    required Widget child,
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFE0D9D0),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: child,
    );
  }

  // ── Profile Card ──────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final color = _kAvatarColors[_colorIdx];
    final raw = _nameCtrl.text.trim();
    final initial = raw.isNotEmpty ? raw[0].toUpperCase() : '?';

    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(color: color.bg, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: color.fg,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C2420),
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
                  'Tap name to edit',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB4B2A9)),
                ),
                if (_nameChanged) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: _saveName,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC1544A),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(
        selectedIndex: _colorIdx,
        onSelected: (i) {
          setState(() => _colorIdx = i);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Partner Card ──────────────────────────────────────────────────────

  Widget _buildPartnerCard() {
    switch (_partnerState) {
      case _PartnerState.none:
        return _buildPartnerNone();
      case _PartnerState.invited:
        return _buildPartnerInvited();
      case _PartnerState.connected:
        return _buildPartnerConnected();
    }
  }

  Widget _buildPartnerNone() {
    return _card(
      child: Column(
        children: [
          _DashedCircle(
            size: 56,
            child: const Icon(Icons.person_add_outlined,
                color: Color(0xFFB4B2A9), size: 24),
          ),
          const SizedBox(height: 12),
          const Text(
            'No partner connected yet',
            style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Invite them to join you on Us',
            style: TextStyle(fontSize: 13, color: Color(0xFFB4B2A9)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sendInvite,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC1544A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Invite your partner',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerInvited() {
    return GestureDetector(
      onLongPress: _simulatePartnerAccepted,
      child: _card(
        backgroundColor: const Color(0xFFFAEEDA),
        borderColor: const Color(0xFFFAC775),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) =>
                  Transform.scale(scale: _pulse.value, child: child),
              child: const Icon(Icons.send_rounded,
                  color: Color(0xFF854F0B), size: 28),
            ),
            const SizedBox(height: 10),
            const Text(
              'Invite sent!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF633806),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Waiting for them to join...',
              style: TextStyle(fontSize: 13, color: Color(0xFF854F0B)),
            ),
            const SizedBox(height: 12),
            _buildAnimatedDots(),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => _openShareSheet(_inviteCode),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF854F0B),
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Resend invite',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: _cancelInvite,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB4B2A9),
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Cancel invite',
                  style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsCtrl,
      builder: (_, child) {
        final t = _dotsCtrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(
                scale: 0.7 + t * 0.6,
                opacity: 0.5 + t * 0.5,
                color: const Color(0xFFC1544A)),
            const SizedBox(width: 5),
            _dot(scale: 1.0, opacity: 0.45, color: const Color(0xFF854F0B)),
            const SizedBox(width: 5),
            _dot(scale: 1.0, opacity: 0.45, color: const Color(0xFF854F0B)),
          ],
        );
      },
    );
  }

  Widget _dot(
      {required double scale,
      required double opacity,
      required Color color}) {
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildPartnerConnected() {
    final color = _kAvatarColors[_partnerColorIdx];
    final initial =
        _partnerName.isNotEmpty ? _partnerName[0].toUpperCase() : 'P';

    return _card(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color.bg, shape: BoxShape.circle),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: color.fg,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _partnerName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2420),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3DE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Connected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3B6D11),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _confirmRemovePartner,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA32D2D),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Remove partner',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Together Since Card ───────────────────────────────────────────────

  Widget _buildTogetherSinceCard() {
    final since = _togetherSince;
    final days = since != null
        ? max(0, DateTime.now().difference(since).inDays)
        : 0;
    final dateLabel =
        since != null ? DateFormat('MMMM yyyy').format(since) : 'Set a date';
    final milestone = _upcomingMilestone();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.favorite_rounded,
                    color: Color(0xFFC1544A), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C2420),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$days days together',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (milestone != null) ...[
            const SizedBox(height: 12),
            _buildMilestoneBanner(milestone),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: _changeTogetherSince,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC1544A),
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Change date',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneBanner(_Milestone m) {
    final label = DateFormat('MMMM d').format(m.date);
    final yearsLabel = m.years == 1 ? '1 year' : '${m.years} years';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Coming up: $yearsLabel on $label',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF854F0B),
        ),
      ),
    );
  }

  // ── Success Overlay ───────────────────────────────────────────────────

  Widget _buildSuccessOverlay() {
    return AnimatedBuilder(
      animation: _successCtrl,
      builder: (_, child) {
        final t = _successCtrl.value;
        final scale =
            t < 0.4 ? Curves.elasticOut.transform(t / 0.4) : 1.0;
        final opacity = t > 0.75
            ? (1.0 - (t - 0.75) / 0.25).clamp(0.0, 1.0)
            : 1.0;

        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF3DE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Color(0xFF3B6D11), size: 40),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _DashedCircle extends StatelessWidget {
  final double size;
  final Widget child;

  const _DashedCircle({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedCirclePainter(),
      child: SizedBox(width: size, height: size, child: Center(child: child)),
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

class _ColorPickerSheet extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ColorPickerSheet({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your color',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2420),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_kAvatarColors.length, (i) {
              final c = _kAvatarColors[i];
              final selected = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelected(i),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? c.fg : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded, color: c.fg, size: 20)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kColorLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            selected ? c.fg : const Color(0xFFB4B2A9),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final String link;

  const _ShareSheet({required this.link});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite your partner',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2420),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this link with your partner to connect on Us.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8C7B72)),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF2C2420)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Copy',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC1544A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // In production: Share.share('Join me on Us — $link')
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC1544A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text(
                'Share link',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
