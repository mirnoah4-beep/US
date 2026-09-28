import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../models/language_provider.dart';
import '../../services/mediation_service.dart';
import '../../theme/app_theme.dart';

/// The only serious screen. Shown ONLY to the person whose own answers were
/// flagged, right after they submitted. Nothing about it reaches the partner.
class MediationSafetyScreen extends StatefulWidget {
  /// The talk the flagged submission belongs to — lets the user close it.
  final String mediationId;
  const MediationSafetyScreen({super.key, required this.mediationId});

  @override
  State<MediationSafetyScreen> createState() => _MediationSafetyScreenState();
}

class _MediationSafetyScreenState extends State<MediationSafetyScreen> {
  bool _closing = false;

  Future<void> _closeTalk() async {
    final coupleId = context.read<AppState>().coupleId;
    final nav = Navigator.of(context);
    setState(() => _closing = true);
    try {
      await MediationService.setState(coupleId, widget.mediationId, 'closed');
    } catch (_) {
      // Closing is a courtesy here; the screen still exits.
    }
    if (mounted) nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_border, color: AppTheme.accentRose, size: 28),
              const SizedBox(height: 16),
              Text(s.medSafetyTitle, style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.25)),
              const SizedBox(height: 12),
              Text(s.medSafetyBody, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.45)),
              const SizedBox(height: 22),
              _Line(Icons.phone_outlined, s.medSafetyEmergency),
              _Line(Icons.support_agent_outlined, s.medSafetyHelpline),
              _Line(Icons.language_outlined, s.medSafetyWeb),
              const Spacer(),
              Text(s.medSafetyPrivate, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4)),
              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentRose,
                  side: const BorderSide(color: AppTheme.accentRose, width: 1.5),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _closing ? null : _closeTalk,
                child: Text(s.medSafetyCloseTalk, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accentRose, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(s.medSafetyOk, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.accentRose),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.35))),
          ],
        ),
      );
}
