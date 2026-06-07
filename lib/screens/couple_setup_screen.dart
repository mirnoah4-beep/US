import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/couple_model.dart';
import '../models/join_result.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

enum _Mode { invite, enter }

class CoupleSetupScreen extends StatefulWidget {
  final String currentUserId;
  final VoidCallback onCoupleActive;

  const CoupleSetupScreen({
    super.key,
    required this.currentUserId,
    required this.onCoupleActive,
  });

  @override
  State<CoupleSetupScreen> createState() => _CoupleSetupScreenState();
}

class _CoupleSetupScreenState extends State<CoupleSetupScreen> {
  _Mode _mode = _Mode.invite;

  // Invite mode
  String? _inviteCode;
  bool _isGenerating = false;
  bool _isCancelling = false;
  bool _navigated = false;
  StreamSubscription<CoupleModel?>? _coupleSub;

  // Enter mode
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  bool _isConnecting = false;

  bool get _isAnyLoading => _isGenerating || _isCancelling || _isConnecting;
  String get _rawDigits => _codeCtrl.text.replaceAll(' ', '');
  bool get _canConnect => _rawDigits.length == 6 && !_isAnyLoading;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    _coupleSub?.cancel();
    super.dispose();
  }

  void _switchMode(_Mode mode) {
    if (_isAnyLoading) return;
    setState(() => _mode = mode);
    if (mode == _Mode.enter) {
      Future.microtask(() => _codeFocus.requestFocus());
    }
  }

  // ── Create invite ──────────────────────────────────────────────────────────

  Future<void> _generateCode() async {
    setState(() => _isGenerating = true);
    try {
      final result =
          await FirestoreService.createInvite(widget.currentUserId);
      if (!mounted) return;
      setState(() {
        _inviteCode = result.code;
      });
      _watchCouple(result.coupleId);
    } catch (_) {
      _showError('Kunne ikke opprette invitasjon. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _watchCouple(String coupleId) {
    _coupleSub?.cancel();
    _coupleSub = FirestoreService.watchCouple(coupleId).listen((couple) {
      if (couple != null && couple.isActive && mounted && !_navigated) {
        _navigated = true;
        widget.onCoupleActive();
      }
    });
  }

  // ── Cancel invite ──────────────────────────────────────────────────────────

  Future<void> _cancelInvite() async {
    if (_inviteCode == null) return;
    setState(() => _isCancelling = true);
    try {
      await FirestoreService.cancelInvite(
          _inviteCode!, widget.currentUserId);
      if (!mounted) return;
      _coupleSub?.cancel();
      setState(() {
        _inviteCode = null;
      });
    } catch (_) {
      _showError('Kunne ikke avbryte invitasjonen. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  // ── Join by code ───────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (!_canConnect) return;
    setState(() => _isConnecting = true);
    try {
      final result = await FirestoreService.joinByCode(
          _rawDigits, widget.currentUserId);
      if (!mounted) return;
      switch (result) {
        case JoinSuccess():
          widget.onCoupleActive();
        case JoinFailure(:final reason, :final debugMessage):
          _showError(
            debugMessage != null
                ? 'Feil: $debugMessage'
                : _failureMessage(reason),
            duration: debugMessage != null
                ? const Duration(seconds: 20)
                : const Duration(seconds: 4),
          );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  String _failureMessage(JoinFailureReason reason) => switch (reason) {
        JoinFailureReason.invalidCode => 'Ugyldig kode.',
        JoinFailureReason.ownInvite => 'Du kan ikke bruke din egen kode.',
        JoinFailureReason.alreadyPartnered =>
          'Denne personen har allerede en partner.',
        JoinFailureReason.inviteExpired => 'Koden er ikke lenger gyldig.',
        JoinFailureReason.networkError => 'Nettverksfeil, prøv igjen.',
      };

  void _showError(String message,
      {Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF993C1D)),
        ),
        backgroundColor: const Color(0xFFFAECE7),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Koble til partner',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inviter partneren din, eller skriv inn koden deres.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _buildToggle(),
              const SizedBox(height: 36),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _mode == _Mode.invite
                      ? _buildInviteMode()
                      : _buildEnterMode(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return SegmentedButton<_Mode>(
      segments: const [
        ButtonSegment(
          value: _Mode.invite,
          label: Text('Inviter partner'),
          icon: Icon(Icons.share_outlined, size: 17),
        ),
        ButtonSegment(
          value: _Mode.enter,
          label: Text('Skriv inn kode'),
          icon: Icon(Icons.keyboard_outlined, size: 17),
        ),
      ],
      selected: {_mode},
      onSelectionChanged:
          _isAnyLoading ? null : (s) => _switchMode(s.first),
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ── Invite mode ────────────────────────────────────────────────────────────

  Widget _buildInviteMode() {
    return Center(
      key: const ValueKey<String>('invite'),
      child: _inviteCode == null
          ? _buildGenerateButton()
          : _buildCodeCard(_inviteCode!),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isAnyLoading ? null : _generateCode,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accentRose,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isGenerating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Generer kode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildCodeCard(String code) {
    final formatted = '${code.substring(0, 3)} ${code.substring(3)}';
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'DIN INVITASJONSKODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatted,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isAnyLoading
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kode kopiert!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRose,
                      side: const BorderSide(
                          color: AppTheme.accentRose, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text(
                      'Kopier kode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'Venter på at partner skal skrive inn koden...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _isAnyLoading ? null : _cancelInvite,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRose,
                side:
                    const BorderSide(color: AppTheme.accentRose, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentRose,
                      ),
                    )
                  : const Text(
                      'Avbryt invitasjon',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Enter code mode ────────────────────────────────────────────────────────

  Widget _buildEnterMode() {
    return SingleChildScrollView(
      key: const ValueKey<String>('enter'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skriv inn koden fra din partner',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _codeCtrl,
              focusNode: _codeFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [_InviteCodeFormatter()],
              textAlign: TextAlign.center,
              enabled: !_isAnyLoading,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000 000',
                hintStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: AppTheme.textPrimary.withValues(alpha: 0.15),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _canConnect ? _connect : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.accentRose.withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Koble til',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input formatter ────────────────────────────────────────────────────────────

class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 6 ? digits.substring(0, 6) : digits;
    final formatted = capped.length > 3
        ? '${capped.substring(0, 3)} ${capped.substring(3)}'
        : capped;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
