import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// The four predefined messages a sender may pick. Ids must match
/// PARTNER_TEMPLATE_IDS in functions/src/notificationStrings.ts — the server
/// rejects anything else.
const kPartnerTemplateIds = <String>[
  'miss_us_time',
  'tonight',
  'date_soon',
  'time_with_you',
];

/// Opens the relationship reminder sheet. Reached from a tapped automatic
/// reminder, never from a permanent Home card.
Future<void> showRelationshipReminderSheet(
  BuildContext context, {
  String reminderType = 'quality_time',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RelationshipReminderSheet(reminderType: reminderType),
  );
}

class RelationshipReminderSheet extends StatefulWidget {
  /// One of 'date', 'quality_time', 'weekly'.
  final String reminderType;

  const RelationshipReminderSheet({super.key, required this.reminderType});

  @override
  State<RelationshipReminderSheet> createState() =>
      _RelationshipReminderSheetState();
}

class _RelationshipReminderSheetState extends State<RelationshipReminderSheet> {
  String _selected = kPartnerTemplateIds.first;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  String _reminderText(AppStrings s) {
    switch (widget.reminderType) {
      case 'date':
        return s.reminderSheetDate;
      case 'weekly':
        return s.reminderSheetWeekly;
      default:
        return s.reminderSheetQualityTime;
    }
  }

  Future<void> _send(AppStrings s) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirestoreService.sendPartnerNotification(_selected);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } on FirebaseFunctionsException catch (e, st) {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'sendPartnerNotification');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e.code) {
          'resource-exhausted' => s.reminderSheetRateLimited,
          'failed-precondition' => s.reminderSheetNoPartner,
          _ => s.reminderSheetSendFailed,
        };
      });
    } catch (e, st) {
      await FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'sendPartnerNotification');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = s.reminderSheetSendFailed;
      });
    }
  }

  void _planSomething() {
    // Reuses the app's existing tab navigation — tab 2 is Plan.
    context.read<AppState>().requestTabNavigation(2);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
          Text(
            s.reminderSheetTitle,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _reminderText(s),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            s.reminderSheetChooseMessage,
            style: const TextStyle(
              color: AppTheme.textSubtle,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final id in kPartnerTemplateIds) _buildOption(s, id),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: AppTheme.heatRedText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          if (_sent) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppTheme.accentGreen, size: 18),
                const SizedBox(width: 8),
                Text(
                  s.reminderSheetSent,
                  style: const TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _buildPrimaryButton(s),
          const SizedBox(height: 10),
          _buildSecondaryButton(s),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                s.reminderSheetDismiss,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(AppStrings s, String id) {
    final selected = _selected == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _sent ? null : () => setState(() => _selected = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentRoseLight : AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.accentRose : AppTheme.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppTheme.accentRose : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.partnerTemplateLabel(id),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(AppStrings s) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (_sending || _sent) ? null : () => _send(s),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentRose,
          disabledBackgroundColor: AppTheme.accentRose.withValues(alpha: 0.4),
          foregroundColor: AppTheme.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.white),
                ),
              )
            : Text(
                s.reminderSheetSend,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildSecondaryButton(AppStrings s) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _planSomething,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.divider),
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          s.reminderSheetPlan,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
