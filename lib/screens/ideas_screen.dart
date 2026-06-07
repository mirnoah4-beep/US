import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/weekly_idea.dart';
import '../models/weekly_ideas_provider.dart';
import '../services/firestore_service.dart';
import '../services/idea_image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/already_pending_dialog.dart';
import '../widgets/calendar_card.dart';
import '../widgets/heart_confirm_dialog.dart';

// ─── Color palettes ───────────────────────────────────────────────────────────

class _Palette {
  final Color bg;
  final Color border;
  final Color icon;
  final Color tagBg;
  final Color tagText;
  const _Palette(this.bg, this.border, this.icon, this.tagBg, this.tagText);
}

const _kPalettes = [
  _Palette(Color(0xFFFAECE7), Color(0xFFF5C4B3), Color(0xFF993C1D), Color(0xFFF5C4B3), Color(0xFF712B13)),
  _Palette(Color(0xFFEAF3DE), Color(0xFFC0DD97), Color(0xFF3B6D11), Color(0xFFC0DD97), Color(0xFF27500A)),
  _Palette(Color(0xFFFAEEDA), Color(0xFFFAC775), Color(0xFF854F0B), Color(0xFFFAC775), Color(0xFF633806)),
  _Palette(Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF0F6E56), Color(0xFF9FE1CB), Color(0xFF085041)),
  _Palette(Color(0xFFFBEAF0), Color(0xFFF4C0D1), Color(0xFF993556), Color(0xFFF4C0D1), Color(0xFF72243E)),
  _Palette(Color(0xFFEEEDFE), Color(0xFFCECBF6), Color(0xFF534AB7), Color(0xFFCECBF6), Color(0xFF3C3489)),
];

// ─── Idea model ───────────────────────────────────────────────────────────────

class _IdeaItem {
  final String id;
  final String titleEn, titleNo;
  final String durationEn, durationNo;
  final String categoryEn, categoryNo;
  final String descEn, descNo;
  final IconData icon;
  final String filter; // '10min' | 'athome' | 'out' | '1hour'
  final int colorIndex;

  const _IdeaItem({
    required this.id,
    required this.titleEn, required this.titleNo,
    required this.durationEn, required this.durationNo,
    required this.categoryEn, required this.categoryNo,
    required this.descEn, required this.descNo,
    required this.icon,
    required this.filter,
    required this.colorIndex,
  });

  String title(bool no) => no ? titleNo : titleEn;
  String duration(bool no) => no ? durationNo : durationEn;
  String category(bool no) => no ? categoryNo : categoryEn;
  String desc(bool no) => no ? descNo : descEn;
}

// TODO: connect to Firestore when backend ready
const List<_IdeaItem> _kIdeas = [
  _IdeaItem(
    id: 'question_cards',
    titleEn: 'Question cards on the couch',
    titleNo: 'Spørsmålskort i sofaen',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Pick a deck of questions and take turns asking each other. No phones, no distractions.',
    descNo: 'Velg et kortstokk med spørsmål og still hverandre på omgang. Ingen telefoner, ingen avbrytelser.',
    icon: Icons.quiz_outlined,
    filter: '10min', colorIndex: 0,
  ),
  _IdeaItem(
    id: 'evening_walk',
    titleEn: 'Evening walk without phones',
    titleNo: 'Kveldstur uten telefoner',
    durationEn: '30 min', durationNo: '30 min',
    categoryEn: 'Out together', categoryNo: 'Ute sammen',
    descEn: 'Leave the phones at home. Walk your neighbourhood and just talk.',
    descNo: 'La telefonene hjemme. Gå i nabolaget og bare prat.',
    icon: Icons.directions_walk_outlined,
    filter: 'out', colorIndex: 1,
  ),
  _IdeaItem(
    id: 'cook_together',
    titleEn: 'Cook a new recipe together',
    titleNo: 'Lag en ny oppskrift sammen',
    durationEn: '45 min', durationNo: '45 min',
    categoryEn: 'At home', categoryNo: 'Hjemme',
    descEn: 'Choose a recipe neither of you has tried. Divide the prep and enjoy it together.',
    descNo: 'Velg en oppskrift ingen av dere har prøvd. Del forberedelsene og nyt det sammen.',
    icon: Icons.restaurant_outlined,
    filter: 'athome', colorIndex: 2,
  ),
  _IdeaItem(
    id: 'tea_night',
    titleEn: 'Tea + dessert night',
    titleNo: 'Te + dessertkveld',
    durationEn: '20 min', durationNo: '20 min',
    categoryEn: 'At home', categoryNo: 'Hjemme',
    descEn: 'Brew your favourite tea, grab something sweet and just be together on the couch.',
    descNo: 'Trekk favorittteen, ta noe søtt og bare vær sammen i sofaen.',
    icon: Icons.local_cafe_outlined,
    filter: 'athome', colorIndex: 3,
  ),
  _IdeaItem(
    id: 'mini_trip',
    titleEn: 'Plan a mini trip together',
    titleNo: 'Planlegg en minitur sammen',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Spend 10 minutes browsing ideas for a weekend away — even if you do not book yet.',
    descNo: 'Bruk 10 minutter på å bla gjennom idéer for en helgetur — selv om dere ikke bestiller ennå.',
    icon: Icons.map_outlined,
    filter: '10min', colorIndex: 4,
  ),
  _IdeaItem(
    id: 'bowling',
    titleEn: 'Bowling or mini-golf',
    titleNo: 'Bowling eller minigolf',
    durationEn: '1 hour+', durationNo: '1 time+',
    categoryEn: '1 hour+', categoryNo: '1 time+',
    descEn: 'Pick something a little silly and competitive. Low pressure, high fun.',
    descNo: 'Velg noe litt tåpelig og konkurransepreget. Lavt press, høy moro.',
    icon: Icons.sports_outlined,
    filter: '1hour', colorIndex: 5,
  ),
  _IdeaItem(
    id: 'coffee_walk',
    titleEn: 'Morning coffee walk',
    titleNo: 'Morgentur med kaffe',
    durationEn: '30 min', durationNo: '30 min',
    categoryEn: 'Out together', categoryNo: 'Ute sammen',
    descEn: 'Start the day together with a walk and a takeaway coffee. Just the two of you.',
    descNo: 'Start dagen sammen med en tur og en takeaway-kaffe. Bare dere to.',
    icon: Icons.coffee_outlined,
    filter: 'out', colorIndex: 0,
  ),
  _IdeaItem(
    id: 'write_letters',
    titleEn: 'Write each other a letter',
    titleNo: 'Skriv hverandre et brev',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Pen and paper. Write one thing you love about them right now and swap.',
    descNo: 'Penn og papir. Skriv én ting du elsker ved dem akkurat nå og bytt.',
    icon: Icons.edit_outlined,
    filter: '10min', colorIndex: 1,
  ),
  _IdeaItem(
    id: 'local_market',
    titleEn: 'Visit a local market',
    titleNo: 'Besøk et lokalt marked',
    durationEn: '1 hour+', durationNo: '1 time+',
    categoryEn: '1 hour+', categoryNo: '1 time+',
    descEn: 'Wander through a market together. Grab a snack and people-watch.',
    descNo: 'Vandre gjennom et marked sammen. Ta en snack og se på folk.',
    icon: Icons.store_outlined,
    filter: '1hour', colorIndex: 2,
  ),
  _IdeaItem(
    id: 'dance_kitchen',
    titleEn: 'Dance in the kitchen',
    titleNo: 'Dans på kjøkkenet',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Put on a favourite song and just dance. It does not have to be good.',
    descNo: 'Sett på en favorittlåt og dans. Det trenger ikke å være bra.',
    icon: Icons.music_note_outlined,
    filter: '10min', colorIndex: 3,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  String _activeFilter = 'all';
  Set<String> _savedIds = {};

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final ids = List<String>.from(snap.data()?['savedIdeaIds'] as List? ?? []);
      if (mounted) setState(() => _savedIds = ids.toSet());
    } catch (_) {}
  }

  Future<void> _toggleSave(String id) async {
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'savedIdeaIds': _savedIds.toList(),
    }).catchError((_) {});
  }

  List<_IdeaItem> get _filtered {
    if (_activeFilter == 'all') return _kIdeas;
    return _kIdeas.where((i) => i.filter == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final isNo = s.isNorwegian;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.ideasTitle,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.ideasSubtitle,
                      style: const TextStyle(
                        color: AppTheme.textSubtle,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: s.ideasAll,
                            active: _activeFilter == 'all',
                            onTap: () => setState(() => _activeFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasChip10min,
                            active: _activeFilter == '10min',
                            onTap: () => setState(() => _activeFilter = '10min'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasFilterAtHome,
                            active: _activeFilter == 'athome',
                            onTap: () => setState(() => _activeFilter = 'athome'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasFilterOut,
                            active: _activeFilter == 'out',
                            onTap: () => setState(() => _activeFilter = 'out'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasFilter1Hour,
                            active: _activeFilter == '1hour',
                            onTap: () => setState(() => _activeFilter = '1hour'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    s.ideasEmpty,
                    style: const TextStyle(color: AppTheme.textSubtle, fontSize: 15),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final idea = filtered[index];
                      final palette = _kPalettes[idea.colorIndex % _kPalettes.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _IdeaCard(
                          key: ValueKey(idea.id),
                          idea: idea,
                          palette: palette,
                          isSaved: _savedIds.contains(idea.id),
                          isNorwegian: isNo,
                          onHeartTap: () => _toggleSave(idea.id),
                          onTap: () => _openDetail(context, idea, palette),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, _IdeaItem idea, _Palette palette) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IdeaDetailSheet(
        idea: idea,
        palette: palette,
        isSaved: _savedIds.contains(idea.id),
        onSave: () {
          Navigator.pop(ctx);
          _toggleSave(idea.id);
        },
        onSend: () {
          () async {
            Navigator.pop(ctx);
            if (!mounted) return;
            final s = context.read<LanguageProvider>().s;
            final isNo = s.isNorwegian;
            final appState = context.read<AppState>();
            final p = context.read<WeeklyIdeasProvider>();
            if (p.sendState == IdeaSendState.waiting) {
              final confirmed = await showDialog<bool>(
                context: context,
                useRootNavigator: true,
                builder: (dCtx) => AlreadyPendingDialog(
                  pendingTitle: p.sentIdea?.title(s.isNorwegian) ?? '',
                  s: s,
                ),
              );
              if (confirmed != true || !mounted) return;
              final ok = await p.cancelForReplacement(appState.coupleId);
              if (!mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isNo
                      ? 'Noe gikk galt – prøv igjen'
                      : 'Something went wrong – try again'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
                return;
              }
            }
            final messenger = ScaffoldMessenger.of(context);
            final coverUrl = await IdeaImageService.fetchCoverUrl(idea.id);
            if (!mounted) return;
            p.sendIdea(
              WeeklyIdea(
                titleNo: idea.titleNo,
                titleEn: idea.titleEn,
                categoryNo: idea.categoryNo,
                categoryEn: idea.categoryEn,
                metaNo: idea.durationNo,
                metaEn: idea.durationEn,
                descriptionNo: idea.descNo,
                descriptionEn: idea.descEn,
                cardColor: palette.bg,
                tagColor: palette.tagBg,
                tagTextColor: palette.tagText,
                icon: idea.icon,
                buttonColor: palette.icon,
              ),
              appState.coupleId,
              appState.userId,
              appState.displayName,
              partnerId: appState.partnerId,
              coverImageUrl: coverUrl,
            );
            messenger.showSnackBar(SnackBar(
              content: Text(s.ideasSentToPartner),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }();
        },
      ),
    );
  }
}

// ─── Pending idea card ────────────────────────────────────────────────────────

class PendingIdeaCard extends StatefulWidget {
  final IncomingIdeaRequest request;
  final String coupleId;
  final String userId;

  const PendingIdeaCard({
    super.key,
    required this.request,
    required this.coupleId,
    required this.userId,
  });

  @override
  State<PendingIdeaCard> createState() => _PendingIdeaCardState();
}

class _PendingIdeaCardState extends State<PendingIdeaCard> {
  bool _responding = false;
  bool _dismissed = false;
  late Future<String?> _imageFuture;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statusSub;

  @override
  void initState() {
    super.initState();
    _imageFuture = Future.value(widget.request.coverImageUrl);
    _subscribeToRequestStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openModal(context);
    });
  }

  void _subscribeToRequestStatus() {
    _statusSub = FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('ideaRequests')
        .doc(widget.request.requestId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (!snap.exists) return;
      final status = snap.data()!['status'] as String?;
      if (status != null && status != 'pending') {
        Navigator.of(context, rootNavigator: true).maybePop();
        setState(() => _dismissed = true);
        _statusSub?.cancel();
        _statusSub = null;
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    // Capture everything from context before any await — respondToRequest()
    // synchronously clears _incomingRequest + notifyListeners(), which causes
    // PendingIdeaCard to be removed from the tree during the async gap, setting
    // mounted=false. All context reads must happen before that point.
    final nav = Navigator.of(context, rootNavigator: true);
    setState(() => _responding = true);
    final provider = context.read<WeeklyIdeasProvider>();
    final coupleId = widget.coupleId;
    final s = context.read<LanguageProvider>().s;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final activity = widget.request.ideaTitle(s.isNorwegian);

    DateTime planDate;

    if (widget.request.proposedAt != null) {
      planDate = widget.request.proposedAt!;
    } else {
      // Show pickers while still mounted — before respondToRequest unmounts us.
      final pickedDate = await _showDatePickerDialog();
      if (!mounted) return;
      if (pickedDate == null) return;

      final pickedTime = await _showTimePickerDialog();
      if (!mounted) return;

      planDate = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );
    }

    // Run both writes in parallel. respondToRequest will unmount this widget
    // as a side effect, but addPlan uses only captured values — no context
    // needed — so it completes successfully regardless.
    await Future.wait([
      provider.respondToRequest(coupleId, widget.request.requestId, true, planDate: planDate),
      FirestoreService.addPlan(
        coupleId: coupleId,
        activity: activity,
        date: planDate,
        sentBy: uid,
        status: 'confirmed',
      ),
    ]);

    // nav was captured from the root navigator before any await — safe to push
    // even though this widget is now unmounted.
    nav.push(RawDialogRoute<void>(
      pageBuilder: (ctx, anim, secAnim) => HeartConfirmDialog(
        displayTitle: s.ideaConfirmedTitle(activity),
        date: planDate,
        s: s,
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierLabel: 'Dismiss',
      transitionDuration: Duration.zero,
    ));
  }

  Future<DateTime?> _showDatePickerDialog() async {
    final s = context.read<LanguageProvider>().s;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    DateTime? result;

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) {
        var displayMonth = DateTime(tomorrow.year, tomorrow.month, 1);
        var selected = tomorrow;

        return StatefulBuilder(
          builder: (_, setDs) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFFFAF7F4),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CalendarCard(
                    displayMonth: displayMonth,
                    selectedDate: selected,
                    eventDates: const {},
                    s: s,
                    onPrevMonth: () => setDs(() {
                      displayMonth = DateTime(displayMonth.year, displayMonth.month - 1, 1);
                    }),
                    onNextMonth: () => setDs(() {
                      displayMonth = DateTime(displayMonth.year, displayMonth.month + 1, 1);
                    }),
                    onSelectDate: (date) {
                      result = date;
                      Navigator.pop(dialogCtx);
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      s.ideaSkipPlan,
                      style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result;
  }

  Future<TimeOfDay> _showTimePickerDialog() async {
    final now = DateTime.now();
    var selected = DateTime(now.year, now.month, now.day, 19, 0);
    final isNo = context.read<LanguageProvider>().isNorwegian;

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFAF7F4),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: selected,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentRose,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isNo ? 'Ferdig' : 'Done',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return TimeOfDay(hour: selected.hour, minute: selected.minute);
  }

  Future<void> _decline() async {
    setState(() => _responding = true);
    await context.read<WeeklyIdeasProvider>().respondToRequest(
      widget.coupleId,
      widget.request.requestId,
      false,
    );
  }

  void _openModal(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.transparent,
        child: _IncomingIdeaSheet(
          request: widget.request,
          imageFuture: _imageFuture,
          onAccept: () {
            Navigator.pop(ctx);
            _accept();
          },
          onDecline: () {
            Navigator.pop(ctx);
            _decline();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final s = context.watch<LanguageProvider>().s;
    final isNo = s.isNorwegian;
    final req = widget.request;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C4B3), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable top section opens the full modal
          GestureDetector(
            onTap: () => _openModal(context),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: _imageFuture,
                  builder: (context, snap) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: snap.hasData && snap.data != null
                          ? CachedNetworkImage(
                              imageUrl: snap.data!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const ColoredBox(color: Color(0xFFE8D5C0)),
                              errorWidget: (context, url, error) =>
                                  const ColoredBox(color: Color(0xFFE8D5C0)),
                            )
                          : const ColoredBox(color: Color(0xFFE8D5C0)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.ideaFromLabel(req.senderName),
                        style: const TextStyle(
                          color: AppTheme.accentRose,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        req.ideaTitle(isNo),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 15,
                          fontFamily: 'Georgia',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (req.ideaMeta(isNo).isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          req.ideaMeta(isNo),
                          style: const TextStyle(
                            color: AppTheme.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (req.proposedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.ideaProposedAt(req.proposedAt!),
                          style: const TextStyle(
                            color: AppTheme.accentRose,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _responding ? null : _accept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentRose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle:
                        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: _responding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('✓ ${s.ideaAccept}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _responding ? null : _decline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSubtle,
                    side: const BorderSide(color: Color(0xFFE0D9D0)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: Text('✕ ${s.ideaDecline}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _dismissed = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB4B2A9),
                side: const BorderSide(color: Color(0xFFE0D9D0)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text(s.ideaLater),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Incoming idea sheet (modal) ──────────────────────────────────────────────

class _IncomingIdeaSheet extends StatelessWidget {
  final IncomingIdeaRequest request;
  final Future<String?> imageFuture;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingIdeaSheet({
    required this.request,
    required this.imageFuture,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final isNo = s.isNorwegian;
    final req = request;
    final initial =
        req.senderName.isNotEmpty ? req.senderName[0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cover image with sender avatar overlay
          Stack(
            children: [
              FutureBuilder<String?>(
                future: imageFuture,
                builder: (context, snap) => SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: snap.hasData && snap.data != null
                      ? CachedNetworkImage(
                          imageUrl: snap.data!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const ColoredBox(color: Color(0xFFE8D5C0)),
                          errorWidget: (context, url, error) =>
                              const ColoredBox(color: Color(0xFFE8D5C0)),
                        )
                      : const ColoredBox(color: Color(0xFFE8D5C0)),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentRose,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.ideaFromPartner(req.senderName),
                  style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                AutoSizeText(
                  req.ideaTitle(isNo),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontFamily: 'Georgia',
                  ),
                  textAlign: TextAlign.center,
                  minFontSize: 14,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (req.ideaMeta(isNo).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    req.ideaMeta(isNo),
                    style: const TextStyle(
                        color: AppTheme.textSubtle, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (req.proposedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.ideaProposedAt(req.proposedAt!),
                    style: const TextStyle(
                        color: AppTheme.textSubtle, fontSize: 12, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentRose,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: Text('✓ ${s.ideaAccept}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSubtle,
                          side: const BorderSide(color: Color(0xFFE0D9D0)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        child: Text('✕ ${s.ideaDecline}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB4B2A9),
                      side: const BorderSide(color: Color(0xFFE0D9D0)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: Text(s.ideaLater),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _IdeaCard extends StatefulWidget {
  final _IdeaItem idea;
  final _Palette palette;
  final bool isSaved;
  final bool isNorwegian;
  final VoidCallback onHeartTap;
  final VoidCallback onTap;

  const _IdeaCard({
    super.key,
    required this.idea,
    required this.palette,
    required this.isSaved,
    required this.isNorwegian,
    required this.onHeartTap,
    required this.onTap,
  });

  @override
  State<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends State<_IdeaCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 2,
      ),
    ]).animate(_heartCtrl);
    _imageFuture = IdeaImageService.fetchCoverUrl(widget.idea.id);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.uid == adminUid;

  Future<void> _pickAndUpload(BuildContext context) async {
    final s = context.read<LanguageProvider>().s;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(s.adminUploading),
      duration: const Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final url = await IdeaImageService.uploadCover(widget.idea.id, picked);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(s.adminUploadSuccess),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3B6D11),
      ));
      if (!context.mounted) return;
      setState(() => _imageFuture = Future.value(url));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isNo = widget.isNorwegian;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: _isAdmin ? () => _pickAndUpload(context) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: FutureBuilder<String?>(
              future: _imageFuture,
              builder: (_, snap) => Stack(
                fit: StackFit.expand,
                children: [
                  // warm placeholder
                  const ColoredBox(color: Color(0xFFC4956A)),
                  // pexels image
                  if (snap.hasData && snap.data != null)
                    CachedNetworkImage(
                      imageUrl: snap.data!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const SizedBox(),
                      errorWidget: (_, _, _) => const SizedBox(),
                    ),
                  // gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                  // content
                  Positioned(
                    bottom: 14,
                    left: 16,
                    right: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.idea.title(isNo),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black54),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  widget.idea.duration(isNo),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _heartCtrl,
                          builder: (context, _) => GestureDetector(
                            onTap: () {
                              _heartCtrl.forward(from: 0);
                              widget.onHeartTap();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12, bottom: 2),
                              child: Transform.scale(
                                scale: _heartScale.value,
                                child: Icon(
                                  widget.isSaved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: widget.isSaved
                                      ? const Color(0xFFFF6B6B)
                                      : Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Detail sheet ─────────────────────────────────────────────────────────────

class _IdeaDetailSheet extends StatelessWidget {
  final _IdeaItem idea;
  final _Palette palette;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback? onSend;

  const _IdeaDetailSheet({
    required this.idea,
    required this.palette,
    required this.isSaved,
    required this.onSave,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final isNo = s.isNorwegian;
    final p = palette;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFD3D1C7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.tagBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              idea.category(isNo),
              style: TextStyle(
                color: p.tagText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            idea.title(isNo),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${idea.duration(isNo)} · ${idea.category(isNo)}',
            style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Text(
              idea.desc(isNo),
              style: const TextStyle(
                color: Color(0xFF2C2420),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRose,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD4A090),
                disabledForegroundColor: Colors.white70,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(onSend != null ? s.homeIdeaSendToPartner : s.ideasAlreadySent),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSave,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentRose, width: 1.5),
                foregroundColor: AppTheme.accentRose,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(s.ideasSaveLater),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                s.ideasDismiss,
                style: const TextStyle(
                  color: Color(0xFFB4B2A9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.accentRose : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.accentRose : const Color(0xFFE0D9D0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF555555),
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

