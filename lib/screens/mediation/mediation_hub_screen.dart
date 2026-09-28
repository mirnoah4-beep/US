import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/app_state.dart';
import '../../models/language_provider.dart';
import '../../models/mediation.dart';
import '../../models/mediation_provider.dart';
import '../../theme/app_theme.dart';
import 'mediation_start_screen.dart';
import 'mediation_talk_screen.dart';

/// "Oss mot problemet" — the simple list: the current talk (if any),
/// active agreements, and a Start button.
class MediationHubScreen extends StatelessWidget {
  /// Opens this talk directly (notification deep link).
  final String? openMediationId;
  const MediationHubScreen({super.key, this.openMediationId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final appState = context.watch<AppState>();
    final provider = context.watch<MediationProvider>();
    provider.init(appState.coupleId);
    final current = provider.current;
    final hasPartner = appState.partnerId.isNotEmpty;

    if (openMediationId != null && provider.initialized) {
      final target = provider.byId(openMediationId!);
      if (target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _openTalk(context, target.id, replace: true);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: Text(s.medTitle, style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(s.medIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 18),
          if (!hasPartner)
            _Card(child: Text(s.medNoPartner, style: const TextStyle(color: AppTheme.textSecondary)))
          else if (current == null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MediationStartScreen())),
              child: Text(s.medStartNew, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            )
          else ...[
            _SectionLabel(s.medOngoing),
            _TalkTile(m: current, s: s, appState: appState, onTap: () => _openTalk(context, current.id)),
          ],
          if (provider.activeAgreements.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionLabel(s.medAgreements),
            for (final m in provider.activeAgreements)
              _TalkTile(m: m, s: s, appState: appState, onTap: () => _openTalk(context, m.id)),
          ],
          if (provider.initialized && provider.items.isEmpty && hasPartner) ...[
            const SizedBox(height: 22),
            Center(child: Text(s.medEmpty, style: const TextStyle(color: AppTheme.textMuted))),
          ],
        ],
      ),
    );
  }

  void _openTalk(BuildContext context, String id, {bool replace = false}) {
    final route = MaterialPageRoute<void>(builder: (_) => MediationTalkScreen(mediationId: id));
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.textPrimary.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: child,
      );
}

class _TalkTile extends StatelessWidget {
  final Mediation m;
  final AppStrings s;
  final AppState appState;
  final VoidCallback onTap;
  const _TalkTile({required this.m, required this.s, required this.appState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = m.createdAt;
    final dateText = date == null ? '' : '${date.day}.${date.month}.${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: _Card(
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: AppTheme.accentRoseLight, borderRadius: BorderRadius.circular(9)),
                child: Icon(m.isActive ? Icons.handshake_outlined : Icons.forum_outlined, color: AppTheme.accentRose, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.medCategory(m.category), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('$dateText · ${s.medStatusLabel(m.status)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
