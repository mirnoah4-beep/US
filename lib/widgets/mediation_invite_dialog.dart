import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/mediation.dart';
import '../models/mediation_provider.dart';
import '../screens/mediation/mediation_hub_screen.dart';
import '../theme/app_theme.dart';

/// Identity of "this talk, in this actionable state, for this user" — the
/// dedup key for the auto-opened dialog. Null when nothing awaits [uid].
///
/// The initiator's own unsent invitation draft is excluded: they are in the
/// middle of writing it, and "your partner wants to work something out"
/// would be wrong.
String? mediationDialogKey(Mediation m, String uid) {
  if (uid.isEmpty || !m.awaitsAction(uid)) return null;
  if (m.status == 'invitationDraft') return null;
  return '${m.id}:${m.status}:${m.round}:${m.agreementRevision}';
}

/// Session-scoped watcher (mounted once in the shell): when the couple's
/// current talk moves into a state the current user must act on, opens
/// [MediationInviteDialog] once for that mediation + state. Driven only by
/// the server-written mediation document via [MediationProvider] — never by
/// push payload text.
class MediationInviteWatcher extends StatefulWidget {
  final Widget child;
  const MediationInviteWatcher({super.key, required this.child});
  @override
  State<MediationInviteWatcher> createState() => _MediationInviteWatcherState();
}

class _MediationInviteWatcherState extends State<MediationInviteWatcher> {
  final Set<String> _shown = {};
  bool _presenting = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final provider = context.watch<MediationProvider>();
    if (state.coupleId.isNotEmpty) provider.init(state.coupleId);
    final m = provider.current;
    final key = m == null ? null : mediationDialogKey(m, state.userId);
    if (key != null && !_shown.contains(key) && !_presenting) {
      _shown.add(key);   // claimed before the frame — a rebuild cannot reopen it
      _presenting = true;
      final mediation = m!;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) { _presenting = false; return; }
        await showMediationInviteDialog(context, mediation);
        _presenting = false;
      });
    }
    return widget.child;
  }
}

Future<void> showMediationInviteDialog(BuildContext context, Mediation m) {
  final s = context.read<LanguageProvider>().s;
  final state = context.read<AppState>();
  final partner = state.partnerName.isNotEmpty ? state.partnerName : (s.isNorwegian ? 'Partneren din' : 'Your partner');
  // Only the server-generated neutral invitation (already on the shared
  // document every member reads) is ever quoted — and only at the invitation
  // step. Nothing private, nothing raw.
  final invitation = m.status == 'invited' ? m.invitationFor(s.isNorwegian ? 'no' : 'en') : null;
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => MediationInviteDialog(s: s, partnerName: partner, invitation: invitation, mediationId: m.id),
  );
}

/// Centered rounded dialog in the incoming-request visual language.
class MediationInviteDialog extends StatelessWidget {
  final AppStrings s;
  final String partnerName;
  final String? invitation;
  final String mediationId;
  const MediationInviteDialog({super.key, required this.s, required this.partnerName, required this.invitation, required this.mediationId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppTheme.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: Color(0xFFF5C4B3), shape: BoxShape.circle),
              child: const Icon(Icons.forum_outlined, color: AppTheme.accentRose, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              s.medInviteDialogTitle(partnerName),
              style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.medInviteDialogBody(partnerName),
              style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (invitation != null && invitation!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.accentRoseLight, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  invitation!,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 46,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => MediationHubScreen(openMediationId: mediationId)),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: Text(s.medInviteDialogOpen),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE0D9D0), width: 1.5),
                  foregroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: Text(s.medInviteDialogNotNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
