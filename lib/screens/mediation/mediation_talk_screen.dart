import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/app_state.dart';
import '../../models/language_provider.dart';
import '../../models/mediation.dart';
import '../../models/mediation_provider.dart';
import '../../services/mediation_service.dart';
import '../../theme/app_theme.dart';
import 'mediation_safety_screen.dart';

/// One talk, rendered by its server-owned status:
/// invited → answering/waiting → summary (+ agreement + handshake) → active,
/// or the neutral paused/closed/expired states.
class MediationTalkScreen extends StatelessWidget {
  final String mediationId;
  const MediationTalkScreen({super.key, required this.mediationId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final appState = context.watch<AppState>();
    final m = context.watch<MediationProvider>().byId(mediationId);
    final uid = appState.userId;
    final partnerName = appState.partnerName.isNotEmpty ? appState.partnerName : (s.isNorwegian ? 'partneren din' : 'your partner');
    final myName = appState.displayName.isNotEmpty ? appState.displayName : (s.isNorwegian ? 'du' : 'you');

    Widget body;
    if (m == null) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentRose));
    } else {
      switch (m.status) {
        case 'invited':
          body = m.isStarter(uid)
              ? _Neutral(icon: Icons.hourglass_empty, title: s.medWaitingForResponse(partnerName), body: null)
              : _InviteResponse(m: m, s: s, partnerName: partnerName);
        case 'answering':
        case 'waiting':
          body = m.hasSubmitted(uid)
              ? _Waiting(m: m, s: s, uid: uid, partnerName: partnerName)
              : _Answers(m: m, s: s, uid: uid, partnerName: partnerName);
        case 'summaryFailed':
          body = _Neutral(
            icon: Icons.refresh, title: s.medSummaryFailed, body: null,
            action: (s.medRetry, () => _run(context, () => MediationService.retrySummary(appState.coupleId, m.id))),
          );
        case 'summary':
        case 'active':
          body = _SummaryAndAgreement(m: m, s: s, uid: uid, myName: myName, partnerName: partnerName, appState: appState);
        case 'paused':
          body = _Neutral(icon: Icons.pause_circle_outline, title: s.medPaused, body: s.medPausedBody);
        case 'closed':
          body = _Neutral(icon: Icons.check_circle_outline, title: s.medClosed, body: null);
        case 'expired':
          body = _Neutral(icon: Icons.schedule, title: s.medExpired, body: s.medExpiredBody);
        default:
          body = _Neutral(icon: Icons.info_outline, title: s.medStatusLabel(m.status), body: null);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: Text(m == null ? s.medTitle : s.medCategory(m.category), style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          if (m != null && m.isOpen)
            PopupMenuButton<String>(
              onSelected: (v) => _run(context, () => MediationService.setState(appState.coupleId, m.id, v)),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'paused', child: Text(s.medPause)),
                PopupMenuItem(value: 'closed', child: Text(s.medClose)),
              ],
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Runs a callable and shows a friendly message on failure.
Future<bool> _run(BuildContext context, Future<void> Function() action, {String? tooSoonText}) async {
  final s = context.read<LanguageProvider>().s;
  try {
    await action();
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    final reason = MediationService.reasonOf(e);
    final text = reason == 'too-soon' && tooSoonText != null ? tooSoonText
        : reason == 'hash-mismatch' ? s.medRevisionChanged
        : reason == 'already-open' ? s.medAlreadyOpen
        : s.medGenericError;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
    return false;
  }
}

// ── Building blocks ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Card({required this.child, this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color ?? AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.textPrimary.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: child,
      );
}

Widget _primaryButton(String label, VoidCallback? onTap, {bool busy = false}) => FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: onTap == null ? AppTheme.divider : AppTheme.accentRose,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: busy ? null : onTap,
      child: busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
    );

Widget _secondaryButton(String label, VoidCallback? onTap) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accentRose,
        side: const BorderSide(color: AppTheme.accentRose, width: 1.5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );

Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.25)),
    );

class _Neutral extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final (String, VoidCallback)? action;
  const _Neutral({required this.icon, required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppTheme.accentRose),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            if (body != null) ...[const SizedBox(height: 8), Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4))],
            if (action != null) ...[const SizedBox(height: 20), _secondaryButton(action!.$1, action!.$2)],
          ],
        ),
      );
}

// ── Invitation (partner picks a time) ───────────────────────────────────────

class _InviteResponse extends StatefulWidget {
  final Mediation m; final AppStrings s; final String partnerName;
  const _InviteResponse({required this.m, required this.s, required this.partnerName});
  @override
  State<_InviteResponse> createState() => _InviteResponseState();
}

class _InviteResponseState extends State<_InviteResponse> {
  bool _busy = false;
  Future<void> _pick(String timing) async {
    final coupleId = context.read<AppState>().coupleId;
    setState(() => _busy = true);
    await _run(context, () => MediationService.respond(coupleId, widget.m.id, timing));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _heading(s.medInvitedTitle(widget.partnerName, s.medCategory(widget.m.category).toLowerCase())),
        Text(s.medInvitedBody, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 18),
        for (final t in const ['now', 'tonight', 'tomorrow']) ...[
          _secondaryButton(
            t == 'now' ? s.medTimingNow : t == 'tonight' ? s.medTimingTonight : s.medTimingTomorrow,
            _busy ? null : () => _pick(t),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ── Private answers ─────────────────────────────────────────────────────────

class _Answers extends StatefulWidget {
  final Mediation m; final AppStrings s; final String uid; final String partnerName;
  const _Answers({required this.m, required this.s, required this.uid, required this.partnerName});
  @override
  State<_Answers> createState() => _AnswersState();
}

class _AnswersState extends State<_Answers> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  StreamSubscription<MediationDraft>? _sub;
  bool _loadedOnce = false;
  bool _busy = false;
  Timer? _autosave;

  @override
  void initState() {
    super.initState();
    final coupleId = context.read<AppState>().coupleId;
    _sub = MediationService.draftStream(coupleId, widget.m.id, widget.uid).listen((d) {
      if (_loadedOnce) return;
      _loadedOnce = true;
      _c1.text = d.whatHappened; _c2.text = d.whatINeed; _c3.text = d.whatICanDo;
      if (mounted) setState(() {});
    });
    for (final c in [_c1, _c2, _c3]) {
      c.addListener(() {
        _autosave?.cancel();
        _autosave = Timer(const Duration(seconds: 2), () => _save(silent: true));
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _autosave?.cancel(); _sub?.cancel();
    _c1.dispose(); _c2.dispose(); _c3.dispose();
    super.dispose();
  }

  MediationDraft get _draft => MediationDraft(whatHappened: _c1.text, whatINeed: _c2.text, whatICanDo: _c3.text);

  Future<bool> _save({bool silent = false}) async {
    final coupleId = context.read<AppState>().coupleId;
    final ok = await _run(context, () => MediationService.saveDraft(coupleId, widget.m.id, widget.uid, _draft));
    if (ok && !silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.medDraftSaved), behavior: SnackBarBehavior.floating));
    }
    return ok;
  }

  Future<void> _submit() async {
    final coupleId = context.read<AppState>().coupleId;
    setState(() => _busy = true);
    _autosave?.cancel();
    try {
      if (!await _save(silent: true)) return;
      if (!mounted) return;
      bool flagged = false;
      final ok = await _run(context, () async { flagged = await MediationService.submit(coupleId, widget.m.id); });
      if (!ok || !mounted) return;
      if (flagged) {
        // Only THIS user ever sees this; the talk itself does not change.
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediationSafetyScreen(mediationId: widget.m.id)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final complete = _draft.isComplete;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (widget.m.timing != null && widget.m.isStarter(widget.uid) && widget.m.timing != 'now')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(s.medTimingChosen(widget.partnerName, widget.m.timing == 'tonight' ? s.medTimingTonight : s.medTimingTomorrow),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        _heading(s.medAnswersTitle),
        Text(s.medAnswersPrivate, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        _Field(label: s.medQ1, controller: _c1),
        _Field(label: s.medQ2, controller: _c2),
        _Field(label: s.medQ3, controller: _c3),
        const SizedBox(height: 6),
        _secondaryButton(s.medSaveDraft, _busy ? null : () => _save()),
        const SizedBox(height: 10),
        _primaryButton(s.medSubmit, complete && !_busy ? _submit : null, busy: _busy),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label; final TextEditingController controller;
  const _Field({required this.label, required this.controller});
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
              maxLines: 4, minLines: 2, maxLength: 2000,
              decoration: InputDecoration(
                counterText: '',
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

// ── Waiting for the partner ─────────────────────────────────────────────────

class _Waiting extends StatefulWidget {
  final Mediation m; final AppStrings s; final String uid; final String partnerName;
  const _Waiting({required this.m, required this.s, required this.uid, required this.partnerName});
  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final both = widget.m.hasSubmitted(widget.m.otherUid(widget.uid));
    if (both) return _Neutral(icon: Icons.auto_awesome_outlined, title: s.medSummarizing, body: null);
    return _Neutral(
      icon: Icons.check_circle_outline, title: s.medWaitingForPartner(widget.partnerName), body: s.medSubmittedLocked,
      action: (s.medNudge, () async {
        if (_busy) return;
        setState(() => _busy = true);
        final coupleId = context.read<AppState>().coupleId;
        final messenger = ScaffoldMessenger.of(context);
        final ok = await _run(context, () => MediationService.nudge(coupleId, widget.m.id), tooSoonText: s.medNudgeTooSoon);
        if (ok) messenger.showSnackBar(SnackBar(content: Text(s.medNudgeSent), behavior: SnackBarBehavior.floating));
        if (mounted) setState(() => _busy = false);
      }),
    );
  }
}

// ── Summary + agreement + handshake ─────────────────────────────────────────

class _SummaryAndAgreement extends StatelessWidget {
  final Mediation m; final AppStrings s; final String uid; final String myName; final String partnerName; final AppState appState;
  const _SummaryAndAgreement({required this.m, required this.s, required this.uid, required this.myName, required this.partnerName, required this.appState});

  String nameOf(String u) => u == uid ? myName : partnerName;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().isNorwegian ? 'no' : 'en';
    final sum = m.summaryFor(lang);
    final agr = m.agreementFor(lang);
    final other = m.otherUid(uid);
    // The partner who did not start is named first.
    final order = [m.partnerUid, m.starterUid];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (m.isActive) _DealDone(s: s, appState: appState),
        _heading(s.medSummaryTitle),
        if (sum != null) ...[
          _Card(child: _labelled(s.medSameTeam, sum.sameTeam)),
          _Card(child: _labelled(s.medDifferent, sum.different)),
          for (final u in order)
            _NeedCard(m: m, s: s, uid: uid, ownerUid: u, name: nameOf(u), text: sum.needs[u] ?? '', editable: !m.isActive && u == uid),
          _Card(color: AppTheme.accentRoseLight, child: _labelled('${s.medIdea} · ${s.medSuggestionLabel}', sum.idea)),
        ],
        const SizedBox(height: 10),
        _heading(s.medAgreementTitle),
        Text(s.medAgreementIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 10),
        if (agr != null) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agr.shared, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.3)),
                const SizedBox(height: 12),
                for (final u in order) ...[
                  Text(s.medDoes(nameOf(u)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentRose)),
                  const SizedBox(height: 2),
                  Text(agr.perPartner[u] ?? '', style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.35)),
                  const SizedBox(height: 10),
                ],
                if (!m.isActive)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _editSheet(context, agr),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.accentRose),
                      child: Text(s.medEditAgreement, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          if (!m.isActive) ...[
            Text(s.medHandshakeHint, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            _HoldToAccept(m: m, s: s, uid: uid, coupleId: appState.coupleId),
            const SizedBox(height: 8),
            Text(
              m.hasAccepted(other) ? s.medPartnerAccepted(partnerName) : '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ],
    );
  }

  Widget _labelled(String label, String text) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentRose, letterSpacing: 0.2)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.4)),
        ],
      );

  Future<void> _editSheet(BuildContext context, MediationAgreementTexts agr) async {
    final shared = TextEditingController(text: agr.shared);
    final mine = TextEditingController(text: agr.perPartner[uid] ?? '');
    final coupleId = appState.coupleId;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFFFAF7F4), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)))),
              _heading(s.medEditAgreement),
              _Field(label: s.medEditShared, controller: shared),
              _Field(label: s.medEditMine, controller: mine),
              Text(s.medEditNote, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              _primaryButton(s.medSave, () async {
                final ok = await _run(ctx, () => MediationService.editAgreement(coupleId, m.id, shared.text, mine.text));
                if (ok && ctx.mounted) Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
    shared.dispose(); mine.dispose();
  }
}

class _NeedCard extends StatefulWidget {
  final Mediation m; final AppStrings s; final String uid; final String ownerUid; final String name; final String text; final bool editable;
  const _NeedCard({required this.m, required this.s, required this.uid, required this.ownerUid, required this.name, required this.text, required this.editable});
  @override
  State<_NeedCard> createState() => _NeedCardState();
}

class _NeedCardState extends State<_NeedCard> {
  bool _editing = false;
  late final _c = TextEditingController(text: widget.text);
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final confirmed = widget.m.needsConfirmed[widget.ownerUid];
    final coupleId = context.read<AppState>().coupleId;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.medNeeds(widget.name), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentRose, letterSpacing: 0.2)),
          const SizedBox(height: 6),
          if (_editing) ...[
            TextField(controller: _c, maxLines: 3, maxLength: 300, decoration: InputDecoration(hintText: s.medCorrectHint, counterText: '')),
            const SizedBox(height: 8),
            _primaryButton(s.medSave, () async {
              final ok = await _run(context, () => MediationService.confirmOrCorrectNeed(coupleId, widget.m.id, _c.text));
              if (ok && mounted) setState(() => _editing = false);
            }),
          ] else ...[
            Text(widget.text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.4)),
            if (widget.editable && confirmed == null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(s.medIsThisRight, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _run(context, () => MediationService.confirmOrCorrectNeed(coupleId, widget.m.id, null)),
                    child: Text(s.medYes, style: const TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _editing = true),
                    child: Text(s.medCorrect, style: const TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Hold ~2 s to accept the CURRENT revision (its hash is sent and verified).
class _HoldToAccept extends StatefulWidget {
  final Mediation m; final AppStrings s; final String uid; final String coupleId;
  const _HoldToAccept({required this.m, required this.s, required this.uid, required this.coupleId});
  @override
  State<_HoldToAccept> createState() => _HoldToAcceptState();
}

class _HoldToAcceptState extends State<_HoldToAccept> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
    ..addStatusListener((st) { if (st == AnimationStatus.completed) _accept(); });
  bool _busy = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _accept() async {
    final hash = widget.m.agreementHash;
    if (hash == null || _busy) return;
    setState(() => _busy = true);
    await _run(context, () => MediationService.accept(widget.coupleId, widget.m.id, hash));
    if (mounted) { _ctrl.reset(); setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final accepted = widget.m.hasAccepted(widget.uid);
    return GestureDetector(
      onTapDown: accepted || _busy ? null : (_) => _ctrl.forward(),
      onTapUp: (_) { if (!_ctrl.isCompleted) _ctrl.reverse(); },
      onTapCancel: () { if (!_ctrl.isCompleted) _ctrl.reverse(); },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Semantics(
          button: true,
          label: accepted ? s.medAccepted : s.medHoldToAccept,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: accepted ? AppTheme.accentRose : AppTheme.accentRoseLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentRose, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!accepted)
                  FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _ctrl.value, child: Container(color: AppTheme.accentRose.withValues(alpha: 0.35))),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.handshake_outlined, size: 20, color: accepted ? Colors.white : AppTheme.accentRose),
                      const SizedBox(width: 8),
                      Text(accepted ? s.medAccepted : s.medHoldToAccept,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: accepted ? Colors.white : AppTheme.accentRose)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealDone extends StatelessWidget {
  final AppStrings s; final AppState appState;
  const _DealDone({required this.s, required this.appState});

  Widget _avatar(String? url, String name) => CircleAvatar(
        radius: 26,
        backgroundColor: AppTheme.accentRoseLight,
        backgroundImage: url != null && url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
        child: url == null || url.isEmpty
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.w700, fontSize: 20))
            : null,
      );

  @override
  Widget build(BuildContext context) => _Card(
        color: AppTheme.accentRoseLight,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _avatar(appState.userAvatarUrl, appState.displayName),
                const SizedBox(width: 6),
                const Icon(Icons.handshake_outlined, color: AppTheme.accentRose),
                const SizedBox(width: 6),
                _avatar(appState.partnerAvatarUrl, appState.partnerName),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.medDealDone, style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
      );
}
