import 'package:cloud_firestore/cloud_firestore.dart';

/// "Oss mot problemet" — client model of couples/{c}/mediations/{id}.
/// Everything here is server-written; the client only ever reads it
/// (plus writes its own private draft, which is not part of this model).
///
/// Flow: drafting → invitationDraft → invited → answering → round (1–3)
///       → agreement → active, or unresolved / paused / closed / expired.
const kMediationCategories = ['communication', 'time', 'money', 'kids', 'chores', 'trust', 'intimacy', 'other'];
const kMediationOpenStatuses = {'drafting', 'invitationDraft', 'invited', 'answering', 'round', 'generationFailed', 'agreement'};
const kMediationMaxRephrases = 3;
const kMediationMaxRounds = 3;

class MediationRoundTexts {
  final String sameTeam;
  final String different;
  final Map<String, String> needs;   // uid → line
  final String proposal;
  const MediationRoundTexts({required this.sameTeam, required this.different, required this.needs, required this.proposal});

  static MediationRoundTexts? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final needs = raw['needs'];
    return MediationRoundTexts(
      sameTeam: raw['sameTeam'] as String? ?? '',
      different: raw['different'] as String? ?? '',
      needs: needs is Map ? needs.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      proposal: raw['proposal'] as String? ?? '',
    );
  }
}

/// One round: the texts per language, who has answered, and — only once
/// BOTH have answered — each partner's choice (happy / almost).
class MediationRound {
  final int number;
  final Map<String, MediationRoundTexts> textsByLang;
  final Map<String, String> whatChangedByLang;
  final Set<String> answeredBy;
  final Map<String, String> feedback;   // uid → happy|almost, revealed only when both answered
  const MediationRound({required this.number, required this.textsByLang, required this.whatChangedByLang, required this.answeredBy, required this.feedback});

  bool hasAnswered(String uid) => answeredBy.contains(uid);
  MediationRoundTexts? textsFor(String lang) => textsByLang[lang] ?? (textsByLang.isEmpty ? null : textsByLang.values.first);
  String? whatChangedFor(String lang) => whatChangedByLang[lang] ?? (whatChangedByLang.isEmpty ? null : whatChangedByLang.values.first);

  static MediationRound? fromMap(int number, Object? raw) {
    if (raw is! Map) return null;
    final texts = raw['texts'];
    final byLang = <String, MediationRoundTexts>{};
    if (texts is Map) {
      texts.forEach((k, v) { final p = MediationRoundTexts.fromMap(v); if (p != null) byLang[k.toString()] = p; });
    }
    final wc = raw['whatChanged'];
    final answered = raw['answered'];
    final fb = raw['feedback'];
    return MediationRound(
      number: number,
      textsByLang: byLang,
      whatChangedByLang: wc is Map ? wc.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      answeredBy: answered is Map ? answered.entries.where((e) => e.value == true).map((e) => e.key.toString()).toSet() : const {},
      feedback: fb is Map ? fb.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
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
  final String initiatorUid;
  final String partnerUid;
  final String status;
  final String? timing;
  final DateTime? createdAt;
  final DateTime? reminderAt;
  final String? failedStage;
  final Map<String, String> invitationByLang;
  final int rephrases;
  final int round;
  final Map<int, MediationRound> rounds;
  final Map<String, String> closingNoteByLang;
  final Map<String, MediationAgreementTexts> agreementByLang;
  final int agreementRevision;
  final String? agreementHash;
  final Set<String> acceptedBy;   // uids whose accept matches the CURRENT hash
  final DateTime? activatedAt;

  const Mediation({
    required this.id,
    required this.category,
    required this.initiatorUid,
    required this.partnerUid,
    required this.status,
    required this.timing,
    required this.createdAt,
    required this.reminderAt,
    required this.failedStage,
    required this.invitationByLang,
    required this.rephrases,
    required this.round,
    required this.rounds,
    required this.closingNoteByLang,
    required this.agreementByLang,
    required this.agreementRevision,
    required this.agreementHash,
    required this.acceptedBy,
    required this.activatedAt,
  });

  bool get isOpen => kMediationOpenStatuses.contains(status);
  bool get isActive => status == 'active';
  bool get isUnresolved => status == 'unresolved';
  bool get hasAgreement => agreementByLang.isNotEmpty;
  bool get canRephrase => rephrases < kMediationMaxRephrases;
  bool get isLastRound => round >= kMediationMaxRounds;
  bool hasAccepted(String uid) => acceptedBy.contains(uid);
  String otherUid(String uid) => uid == initiatorUid ? partnerUid : initiatorUid;
  bool isInitiator(String uid) => uid == initiatorUid;
  MediationRound? get currentRound => rounds[round];

  /// True when the talk is waiting for [uid] to do something: approve their
  /// invitation draft, respond to / answer an invitation, give round
  /// feedback, or accept the agreement.
  bool awaitsAction(String uid) => switch (status) {
        'invitationDraft' => isInitiator(uid),
        'invited' || 'answering' => !isInitiator(uid),
        'round' => !(currentRound?.hasAnswered(uid) ?? false),
        'agreement' => !hasAccepted(uid),
        _ => false,
      };

  /// Each partner reads the text in their own language; falls back to
  /// whatever language exists.
  String? invitationFor(String lang) =>
      invitationByLang[lang] ?? (invitationByLang.isEmpty ? null : invitationByLang.values.first);
  MediationAgreementTexts? agreementFor(String lang) =>
      agreementByLang[lang] ?? (agreementByLang.isEmpty ? null : agreementByLang.values.first);
  String? closingNoteFor(String lang) =>
      closingNoteByLang[lang] ?? (closingNoteByLang.isEmpty ? null : closingNoteByLang.values.first);

  static DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

  static Mediation? fromMap(String id, Map<String, dynamic>? d) {
    if (d == null) return null;
    final initiator = d['initiatorUid'];
    final partner = d['partnerUid'];
    if (initiator is! String || partner is! String) return null;
    final invitation = d['invitation'];
    final roundsRaw = d['rounds'];
    final agreement = d['agreement'];
    final closingNote = d['closingNote'];
    final hash = agreement is Map ? agreement['hash'] as String? : null;
    final accepts = agreement is Map ? agreement['accepts'] : null;
    final acceptedBy = <String>{};
    if (accepts is Map && hash != null) {
      accepts.forEach((k, v) { if (v is Map && v['hash'] == hash) acceptedBy.add(k.toString()); });
    }
    final rounds = <int, MediationRound>{};
    if (roundsRaw is Map) {
      roundsRaw.forEach((k, v) {
        final n = int.tryParse(k.toString());
        if (n == null) return;
        final r = MediationRound.fromMap(n, v);
        if (r != null) rounds[n] = r;
      });
    }
    final invTexts = invitation is Map ? invitation['texts'] : null;
    final agrTexts = agreement is Map ? agreement['texts'] : null;
    final agreementByLang = <String, MediationAgreementTexts>{};
    if (agrTexts is Map) {
      agrTexts.forEach((k, v) { final p = MediationAgreementTexts.fromMap(v); if (p != null) agreementByLang[k.toString()] = p; });
    }
    return Mediation(
      id: id,
      category: d['category'] as String? ?? 'other',
      initiatorUid: initiator,
      partnerUid: partner,
      status: d['status'] as String? ?? 'drafting',
      timing: d['timing'] as String?,
      createdAt: _ts(d['createdAt']),
      reminderAt: _ts(d['reminderAt']),
      failedStage: d['failedStage'] as String?,
      invitationByLang: invTexts is Map ? invTexts.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      rephrases: invitation is Map ? (invitation['rephrases'] as num?)?.toInt() ?? 0 : 0,
      round: (d['round'] as num?)?.toInt() ?? 0,
      rounds: rounds,
      closingNoteByLang: closingNote is Map ? closingNote.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      agreementByLang: agreementByLang,
      agreementRevision: agreement is Map ? (agreement['revision'] as num?)?.toInt() ?? 0 : 0,
      agreementHash: hash,
      acceptedBy: acceptedBy,
      activatedAt: agreement is Map ? _ts(agreement['activatedAt']) : null,
    );
  }

  static Mediation? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => fromMap(doc.id, doc.data());
}

/// The user's own private draft (couples/{c}/mediations/{id}/private/{uid}).
/// One doc per user at a time; its [kind] follows the stage.
class MediationDraft {
  final String kind;      // topic | answer | feedback | '' (none)
  final String topic;     // initiator: what to bring up
  final String wish;      // initiator: what should get better
  final String view;      // partner: how they see it
  final String need;      // partner: what they need
  final String feedback;  // happy | almost | ''
  final String addition;  // optional short tweak
  final int round;
  final bool locked;      // draft == false → submitted, read-only
  const MediationDraft({
    this.kind = '', this.topic = '', this.wish = '', this.view = '', this.need = '',
    this.feedback = '', this.addition = '', this.round = 0, this.locked = false,
  });

  static MediationDraft fromMap(Map<String, dynamic>? d) => d == null
      ? const MediationDraft()
      : MediationDraft(
          kind: d['kind'] as String? ?? '',
          topic: d['topic'] as String? ?? '',
          wish: d['wish'] as String? ?? '',
          view: d['view'] as String? ?? '',
          need: d['need'] as String? ?? '',
          feedback: d['feedback'] as String? ?? '',
          addition: d['addition'] as String? ?? '',
          round: (d['round'] as num?)?.toInt() ?? 0,
          locked: d['draft'] == false,
        );

  bool get topicComplete => topic.trim().isNotEmpty && wish.trim().isNotEmpty;
  bool get answerComplete => view.trim().isNotEmpty && need.trim().isNotEmpty;
  bool get feedbackComplete => feedback == 'happy' || feedback == 'almost';

  /// Exactly the keys the rules allow for this kind (draft:true, updatedAt
  /// is added by the service).
  Map<String, Object> toMap() => switch (kind) {
        'topic' => {'kind': 'topic', 'topic': topic, 'wish': wish},
        'answer' => {'kind': 'answer', 'view': view, 'need': need},
        'feedback' => {'kind': 'feedback', 'round': round, 'feedback': feedback, 'addition': addition},
        _ => const {},
      };
}
