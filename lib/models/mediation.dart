import 'package:cloud_firestore/cloud_firestore.dart';

/// "Oss mot problemet" — client model of couples/{c}/mediations/{id}.
/// Everything here is server-written; the client only ever reads it
/// (plus writes its own private draft, which is not part of this model).
const kMediationCategories = ['communication', 'time', 'money', 'kids', 'chores', 'trust', 'intimacy', 'other'];
const kMediationOpenStatuses = {'invited', 'answering', 'waiting', 'summary', 'summaryFailed'};

class MediationSummaryTexts {
  final String sameTeam;
  final String different;
  final Map<String, String> needs;   // uid → line
  final String idea;
  const MediationSummaryTexts({required this.sameTeam, required this.different, required this.needs, required this.idea});

  static MediationSummaryTexts? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final needs = raw['needs'];
    return MediationSummaryTexts(
      sameTeam: raw['sameTeam'] as String? ?? '',
      different: raw['different'] as String? ?? '',
      needs: needs is Map ? needs.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      idea: raw['idea'] as String? ?? '',
    );
  }
}

class MediationAgreementTexts {
  final String shared;
  final Map<String, String> perPartner;
  const MediationAgreementTexts({required this.shared, required this.perPartner});

  static MediationAgreementTexts? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final pp = raw['perPartner'];
    return MediationAgreementTexts(
      shared: raw['shared'] as String? ?? '',
      perPartner: pp is Map ? pp.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
    );
  }
}

class Mediation {
  final String id;
  final String category;
  final String starterUid;
  final String partnerUid;
  final String status;
  final String? timing;
  final DateTime? createdAt;
  final DateTime? reminderAt;
  final Set<String> submittedBy;
  final Map<String, MediationSummaryTexts> summaryByLang;
  final Map<String, String> needsConfirmed;
  final Map<String, MediationAgreementTexts> agreementByLang;
  final int agreementRevision;
  final String? agreementHash;
  final Set<String> acceptedBy;   // uids whose accept matches the CURRENT hash
  final DateTime? activatedAt;

  const Mediation({
    required this.id,
    required this.category,
    required this.starterUid,
    required this.partnerUid,
    required this.status,
    required this.timing,
    required this.createdAt,
    required this.reminderAt,
    required this.submittedBy,
    required this.summaryByLang,
    required this.needsConfirmed,
    required this.agreementByLang,
    required this.agreementRevision,
    required this.agreementHash,
    required this.acceptedBy,
    required this.activatedAt,
  });

  bool get isOpen => kMediationOpenStatuses.contains(status);
  bool get isActive => status == 'active';
  bool get hasSummary => summaryByLang.isNotEmpty;
  bool hasSubmitted(String uid) => submittedBy.contains(uid);
  bool hasAccepted(String uid) => acceptedBy.contains(uid);
  String otherUid(String uid) => uid == starterUid ? partnerUid : starterUid;
  bool isStarter(String uid) => uid == starterUid;

  /// Each partner reads the text in their own language; falls back to
  /// whatever language exists.
  MediationSummaryTexts? summaryFor(String lang) =>
      summaryByLang[lang] ?? (summaryByLang.isEmpty ? null : summaryByLang.values.first);
  MediationAgreementTexts? agreementFor(String lang) =>
      agreementByLang[lang] ?? (agreementByLang.isEmpty ? null : agreementByLang.values.first);

  static DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

  static Mediation? fromMap(String id, Map<String, dynamic>? d) {
    if (d == null) return null;
    final starter = d['starterUid'];
    final partner = d['partnerUid'];
    if (starter is! String || partner is! String) return null;
    final submitted = d['submitted'];
    final summary = d['summary'];
    final agreement = d['agreement'];
    final hash = agreement is Map ? agreement['hash'] as String? : null;
    final accepts = agreement is Map ? agreement['accepts'] : null;
    final acceptedBy = <String>{};
    if (accepts is Map && hash != null) {
      accepts.forEach((k, v) { if (v is Map && v['hash'] == hash) acceptedBy.add(k.toString()); });
    }
    Map<String, T> byLang<T>(Object? texts, T? Function(Object?) parse) {
      final out = <String, T>{};
      if (texts is Map) {
        texts.forEach((k, v) { final p = parse(v); if (p != null) out[k.toString()] = p; });
      }
      return out;
    }
    final needsConfirmedRaw = summary is Map ? summary['needsConfirmed'] : null;
    return Mediation(
      id: id,
      category: d['category'] as String? ?? 'other',
      starterUid: starter,
      partnerUid: partner,
      status: d['status'] as String? ?? 'invited',
      timing: d['timing'] as String?,
      createdAt: _ts(d['createdAt']),
      reminderAt: _ts(d['reminderAt']),
      submittedBy: submitted is Map ? submitted.entries.where((e) => e.value == true).map((e) => e.key.toString()).toSet() : const {},
      summaryByLang: byLang(summary is Map ? summary['texts'] : null, MediationSummaryTexts.fromMap),
      needsConfirmed: needsConfirmedRaw is Map ? needsConfirmedRaw.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      agreementByLang: byLang(agreement is Map ? agreement['texts'] : null, MediationAgreementTexts.fromMap),
      agreementRevision: agreement is Map ? (agreement['revision'] as num?)?.toInt() ?? 0 : 0,
      agreementHash: hash,
      acceptedBy: acceptedBy,
      activatedAt: agreement is Map ? _ts(agreement['activatedAt']) : null,
    );
  }

  static Mediation? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => fromMap(doc.id, doc.data());
}

/// The user's own private draft (couples/{c}/mediations/{id}/private/{uid}).
class MediationDraft {
  final String whatHappened;
  final String whatINeed;
  final String whatICanDo;
  final bool locked;   // draft == false → submitted, read-only
  const MediationDraft({this.whatHappened = '', this.whatINeed = '', this.whatICanDo = '', this.locked = false});

  static MediationDraft fromMap(Map<String, dynamic>? d) => d == null
      ? const MediationDraft()
      : MediationDraft(
          whatHappened: d['whatHappened'] as String? ?? '',
          whatINeed: d['whatINeed'] as String? ?? '',
          whatICanDo: d['whatICanDo'] as String? ?? '',
          locked: d['draft'] == false,
        );

  bool get isComplete => whatHappened.trim().isNotEmpty && whatINeed.trim().isNotEmpty && whatICanDo.trim().isNotEmpty;
}
