import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/mediation.dart';
import '../models/mediation_provider.dart';
import '../screens/mediation/mediation_hub_screen.dart';
import '../theme/app_theme.dart';

/// The talk in [provider] that is waiting on [uid], or null.
Mediation? mediationAwaiting(MediationProvider provider, String uid) {
  final m = provider.current;
  return m != null && uid.isNotEmpty && m.awaitsAction(uid) ? m : null;
}

/// Slim one-line card on Home: "[Partner] venter på deg" → opens the talk.
/// Renders nothing unless a talk awaits the current user.
class MediationWaitingBanner extends StatelessWidget {
  const MediationWaitingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final provider = context.watch<MediationProvider>();
    if (state.coupleId.isNotEmpty) provider.init(state.coupleId);
    final m = mediationAwaiting(provider, state.userId);
    if (m == null) return const SizedBox.shrink();
    final s = context.watch<LanguageProvider>().s;
    final partner = state.partnerName.isNotEmpty ? state.partnerName : (s.isNorwegian ? 'Partneren din' : 'Your partner');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(builder: (_) => MediationHubScreen(openMediationId: m.id)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.textPrimary.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: AppTheme.accentRoseLight, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.forum_outlined, color: AppTheme.accentRose, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.medWaitingOnYou(partner),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rose dot for entry cards when a talk awaits the current user.
class MediationBadgeDot extends StatelessWidget {
  const MediationBadgeDot({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final provider = context.watch<MediationProvider>();
    if (state.coupleId.isNotEmpty) provider.init(state.coupleId);
    if (mediationAwaiting(provider, state.userId) == null) return const SizedBox.shrink();
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.only(right: 6),
      decoration: const BoxDecoration(color: AppTheme.accentRose, shape: BoxShape.circle),
    );
  }
}
