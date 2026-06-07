import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/weekly_ideas_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_card.dart';
import 'couple_game_screen.dart';
import 'ideas_screen.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _PlannedDate {
  final String id;
  final String activity;
  final DateTime date;
  String status; // 'pending' | 'confirmed'
  final DateTime createdAt;

  _PlannedDate({
    required this.id,
    required this.activity,
    required this.date,
    required this.status,
    required this.createdAt,
  });

  factory _PlannedDate.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return _PlannedDate(
      id: doc.id,
      activity: d['activity'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late DateTime _selectedDate;
  late DateTime _displayMonth;
  List<_PlannedDate> _plannedDates = [];
  String _coupleId = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _planSub;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _displayMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coupleId = Provider.of<AppState>(context, listen: false).coupleId;
    if (coupleId != _coupleId && coupleId.isNotEmpty) {
      _coupleId = coupleId;
      _planSub?.cancel();
      _planSub = FirestoreService.weeklyPlanStream(coupleId).listen((snap) {
        if (!mounted) return;
        setState(() {
          _plannedDates = snap.docs
              .map((d) => _PlannedDate.fromFirestore(d))
              .toList();
        });
      });
    }
  }

  @override
  void dispose() {
    _planSub?.cancel();
    super.dispose();
  }

  Future<void> _addDate(String activity) async {
    if (_coupleId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await FirestoreService.addPlan(
      coupleId: _coupleId,
      activity: activity,
      date: _selectedDate,
      sentBy: uid,
    );
  }

  Future<void> _confirmDate(String id) async {
    if (_coupleId.isEmpty) return;
    await FirestoreService.confirmPlan(_coupleId, id);
  }

  Future<void> _deletePlan(String id) async {
    if (_coupleId.isEmpty) return;
    await FirestoreService.deletePlan(_coupleId, id);
  }

  Set<DateTime> get _eventDateSet => _plannedDates
      .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
      .toSet();

  List<_PlannedDate> get _upcomingDates {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    return _plannedDates
        .where((d) => !d.date.isBefore(todayNorm))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final provider = context.watch<WeeklyIdeasProvider>();
    final appState = context.watch<AppState>();
    final incoming = provider.incomingRequest;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 24),
            Text(s.planTitle, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 26, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(s.planSubtitle, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
            const SizedBox(height: 22),
            if (incoming != null) ...[
              Text(
                s.ideaWaiting.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accentRose,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              PendingIdeaCard(
                key: ValueKey(incoming.requestId),
                request: incoming,
                coupleId: appState.coupleId,
                userId: appState.userId,
              ),
              const SizedBox(height: 24),
            ],
            _SectionLabel(s.planChooseDate),
            const SizedBox(height: 10),
            CalendarCard(
              displayMonth: _displayMonth,
              selectedDate: _selectedDate,
              eventDates: _eventDateSet,
              s: s,
              onPrevMonth: () => setState(() {
                _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
              }),
              onNextMonth: () => setState(() {
                _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
              }),
              onSelectDate: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openPlanSheet(context, s),
                icon: const Icon(Icons.add),
                label: Text(s.planDateButton),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel(s.planUpcomingSection),
            const SizedBox(height: 10),
            _UpcomingCard(
              dates: _upcomingDates,
              s: s,
              onConfirm: _confirmDate,
              onDelete: _deletePlan,
            ),
            const SizedBox(height: 24),
            _SectionLabel(s.planCoupleGameSection),
            const SizedBox(height: 10),
            _CoupleGameCard(s: s),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _openPlanSheet(BuildContext context, AppStrings s) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlanDateSheet(
        selectedDate: _selectedDate,
        onConfirm: (activity) {
          Navigator.pop(ctx);
          _addDate(activity).catchError((_) {});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.planProposalSent),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        },
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB4B2A9), letterSpacing: 0.8),
    );
  }
}

// ─── Upcoming card ────────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  final List<_PlannedDate> dates;
  final AppStrings s;
  final ValueChanged<String> onConfirm;
  final Future<void> Function(String id) onDelete;

  const _UpcomingCard({
    required this.dates,
    required this.s,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D9D0)),
      ),
      clipBehavior: Clip.hardEdge,
      child: dates.isEmpty ? _buildEmpty() : _buildList(context),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, color: Color(0xFFD3D1C7), size: 32),
          const SizedBox(height: 12),
          Text(s.planNoUpcomingTitle, style: const TextStyle(color: AppTheme.textSubtle, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(s.planNoUpcomingSub, style: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < dates.length; i++) ...[
          Dismissible(
            key: ValueKey(dates[i].id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) => _CancelPlanDialog(date: dates[i], s: s),
              );
              return result == true;
            },
            onDismissed: (_) => onDelete(dates[i].id),
            background: const SizedBox.shrink(),
            secondaryBackground: Container(
              color: const Color(0xFFD32F2F),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            ),
            child: _UpcomingRow(date: dates[i], s: s, onConfirm: () => onConfirm(dates[i].id)),
          ),
          if (i < dates.length - 1)
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFF1EFE8), indent: 16, endIndent: 16),
        ],
      ],
    );
  }
}

// ─── Cancel plan confirmation dialog ─────────────────────────────────────────

class _CancelPlanDialog extends StatelessWidget {
  final _PlannedDate date;
  final AppStrings s;

  const _CancelPlanDialog({required this.date, required this.s});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFAF7F4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        s.planCancelConfirmTitle,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
      ),
      content: Text(
        '${s.planActivityLabel(date.activity)}\n${s.planFormatDate(date.date)}',
        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A1A1A),
                  side: const BorderSide(color: Color(0xFFE0D9D0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(s.planKeepButton, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(s.planCancelButton, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final _PlannedDate date;
  final AppStrings s;
  final VoidCallback onConfirm;

  const _UpcomingRow({required this.date, required this.s, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = date.status == 'confirmed';
    final squareBg = isConfirmed ? const Color(0xFFFAECE7) : const Color(0xFFFAEEDA);
    final dayColor = isConfirmed ? AppTheme.accentRose : const Color(0xFF854F0B);
    final monthColor = isConfirmed ? const Color(0xFF993C1D) : const Color(0xFF854F0B);
    final badgeBg = isConfirmed ? const Color(0xFFEAF3DE) : const Color(0xFFFAEEDA);
    final badgeText = isConfirmed ? const Color(0xFF3B6D11) : const Color(0xFF633806);
    final badgeLabel = isConfirmed ? s.planConfirmedBadge : s.planPendingBadge;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Date square
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: squareBg, borderRadius: BorderRadius.circular(10)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${date.date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dayColor, height: 1)),
                Text(s.planMonthNamesShort[date.date.month - 1].toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: monthColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.planActivityLabel(date.activity),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(s.planFormatDate(date.date),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isConfirmed ? null : onConfirm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
              child: Text(badgeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeText)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan date sheet ──────────────────────────────────────────────────────────

class _Activity {
  final String id;
  final IconData icon;
  const _Activity(this.id, this.icon);
}

const _kActivities = [
  _Activity('walk', Icons.directions_walk_outlined),
  _Activity('home_date', Icons.home_outlined),
  _Activity('date_night', Icons.star_outline),
  _Activity('game', Icons.sports_esports_outlined),
  _Activity('coffee', Icons.local_cafe_outlined),
  _Activity('other', Icons.add_circle_outline),
];

class _PlanDateSheet extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<String> onConfirm;

  const _PlanDateSheet({required this.selectedDate, required this.onConfirm});

  @override
  State<_PlanDateSheet> createState() => _PlanDateSheetState();
}

class _PlanDateSheetState extends State<_PlanDateSheet> {
  String? _selected;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(s.planSheetTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          Text(s.planSheetSub, style: const TextStyle(fontSize: 13, color: AppTheme.textSubtle)),
          const SizedBox(height: 16),
          _buildGrid(s),
          if (_selected == 'other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customCtrl,
              maxLines: 2,
              maxLength: 100,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: s.planCustomHint,
                hintStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D9D0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D9D0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentRose)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected != null ? () => widget.onConfirm(_selected!) : null,
              style: FilledButton.styleFrom(
                backgroundColor: _selected != null ? AppTheme.accentRose : const Color(0xFFE0D9D0),
                foregroundColor: _selected != null ? Colors.white : const Color(0xFFB4B2A9),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(s.planSendProposal),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.logCancel, style: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(AppStrings s) {
    final rows = <Widget>[];
    for (int i = 0; i < _kActivities.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      final right = i + 1 < _kActivities.length ? _kActivities[i + 1] : null;
      rows.add(Row(
        children: [
          Expanded(child: _chip(_kActivities[i], s)),
          const SizedBox(width: 10),
          Expanded(child: right != null ? _chip(right, s) : const SizedBox()),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _chip(_Activity act, AppStrings s) {
    final isSelected = _selected == act.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = act.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAECE7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentRose : const Color(0xFFE0D9D0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(act.icon, size: 22, color: isSelected ? AppTheme.accentRose : AppTheme.textSubtle),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.planActivityLabel(act.id),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF4A1B0C) : const Color(0xFF2C2420),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Couple game card ─────────────────────────────────────────────────────────

class _CoupleGameCard extends StatelessWidget {
  final AppStrings s;
  const _CoupleGameCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAECE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C4B3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF5C4B3), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF993C1D), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.coupleGameLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF993C1D))),
                const SizedBox(height: 2),
                Text(s.coupleGameTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF4A1B0C))),
                const SizedBox(height: 2),
                Text(s.planCoupleGameSub, style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const CoupleGameScreen()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(s.coupleGameStart),
          ),
        ],
      ),
    );
  }
}
