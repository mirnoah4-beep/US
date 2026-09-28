import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../models/language_provider.dart';
import '../../models/mediation.dart';
import '../../services/mediation_service.dart';
import '../../theme/app_theme.dart';
import 'mediation_talk_screen.dart';

/// Step 1: pick a category → "Inviter [partner]".
class MediationStartScreen extends StatefulWidget {
  const MediationStartScreen({super.key});
  @override
  State<MediationStartScreen> createState() => _MediationStartScreenState();
}

class _MediationStartScreenState extends State<MediationStartScreen> {
  String? _category;
  bool _busy = false;

  Future<void> _invite() async {
    final s = context.read<LanguageProvider>().s;
    final appState = context.read<AppState>();
    if (_category == null) return;
    setState(() => _busy = true);
    try {
      final id = await MediationService.create(appState.coupleId, _category!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MediationTalkScreen(mediationId: id)));
    } catch (e) {
      if (!mounted) return;
      final reason = MediationService.reasonOf(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reason == 'already-open' ? s.medAlreadyOpen : s.medGenericError),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final partner = context.watch<AppState>().partnerName;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: AppTheme.background, elevation: 0, foregroundColor: AppTheme.textPrimary),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(s.medPickCategory, style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.25)),
                const SizedBox(height: 18),
                for (final c in kMediationCategories)
                  _CategoryCard(label: s.medCategory(c), selected: _category == c, onTap: () => setState(() => _category = c)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _category != null ? AppTheme.accentRose : AppTheme.divider,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _category == null || _busy ? null : _invite,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(s.medInvite(partner.isNotEmpty ? partner : '…'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentRoseLight : AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppTheme.accentRose : AppTheme.divider, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: selected ? AppTheme.accentRose : AppTheme.textPrimary))),
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppTheme.accentRose : Colors.transparent, border: Border.all(color: selected ? AppTheme.accentRose : AppTheme.divider, width: 2)),
                child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      );
}
