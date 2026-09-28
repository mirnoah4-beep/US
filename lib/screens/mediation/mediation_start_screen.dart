import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../models/language_provider.dart';
import '../../models/mediation.dart';
import '../../services/mediation_service.dart';
import '../../theme/app_theme.dart';
import 'mediation_safety_screen.dart';
import 'mediation_talk_screen.dart';

/// Step 1 (initiator): pick a category, write privately what to bring up
/// and what should get better → "Lag invitasjon". The partner never sees
/// these words; they get the neutral invitation the server writes.
class MediationStartScreen extends StatefulWidget {
  const MediationStartScreen({super.key});
  @override
  State<MediationStartScreen> createState() => _MediationStartScreenState();
}

class _MediationStartScreenState extends State<MediationStartScreen> {
  String? _category;
  final _topic = TextEditingController();
  final _wish = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _topic.addListener(() => setState(() {}));
    _wish.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _topic.dispose();
    _wish.dispose();
    super.dispose();
  }

  bool get _complete => _category != null && _topic.text.trim().isNotEmpty && _wish.text.trim().isNotEmpty;

  Future<void> _createInvitation() async {
    final s = context.read<LanguageProvider>().s;
    final appState = context.read<AppState>();
    if (!_complete) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final coupleId = appState.coupleId;
      final id = await MediationService.create(coupleId, _category!);
      await MediationService.saveDraft(coupleId, id, appState.userId, MediationDraft(kind: 'topic', topic: _topic.text, wish: _wish.text));
      final flagged = await MediationService.submitTopic(coupleId, id);
      if (!mounted) return;
      if (flagged) {
        // Only THIS user ever sees this; the talk stays a private draft.
        nav.pushReplacement(MaterialPageRoute(builder: (_) => MediationSafetyScreen(mediationId: id)));
      } else {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => MediationTalkScreen(mediationId: id)));
      }
    } catch (e) {
      if (!mounted) return;
      final reason = MediationService.reasonOf(e);
      messenger.showSnackBar(SnackBar(
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
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final c in kMediationCategories)
                      _CategoryChip(label: s.medCategory(c), selected: _category == c, onTap: () => setState(() => _category = c)),
                  ],
                ),
                const SizedBox(height: 26),
                Text(s.medTopicTitle, style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(s.medTopicPrivate, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                MediationField(label: s.medTopicQ, controller: _topic, maxLength: 1000),
                MediationField(label: s.medWishQ, controller: _wish, maxLength: 1000),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _complete ? AppTheme.accentRose : AppTheme.divider,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: !_complete || _busy ? null : _createInvitation,
              child: _busy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(s.medPreparing, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    )
                  : Text(s.medMakeInvitation, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentRose : AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppTheme.accentRose : AppTheme.divider),
          ),
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppTheme.textPrimary)),
        ),
      );
}

/// Shared labelled multi-line field (also used by the talk screen).
class MediationField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final int maxLength;
  final int minLines;
  const MediationField({super.key, required this.label, required this.controller, this.hint, this.maxLength = 2000, this.minLines = 2});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              maxLines: 5, minLines: minLines, maxLength: maxLength,
              decoration: InputDecoration(
                counterText: '', hintText: hint,
                filled: true, fillColor: AppTheme.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.accentRose, width: 1.5)),
              ),
            ),
          ],
        ),
      );
}
