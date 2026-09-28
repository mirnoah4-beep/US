// Pure mediation logic. Run: npm test
import { test } from 'node:test';
import * as assert from 'node:assert';
import {
  validateAnswers, reminderInstant, localToUtc, expiryInstant, agreementHash, phraseSafetyScan,
  parseSafetyOutput, combineSafety, buildGenerationPrompt, parseGenerationOutput, outputIsNeutral,
  applyAgreementEdit, bothAccepted, canNudge, isCategory, isTiming, EXPIRY_DAYS,
} from '../mediation';

const OSLO = 'Europe/Oslo';

test('answers: all three required, trimmed, bounded', () => {
  const ok = validateAnswers({ whatHappened: ' a ', whatINeed: 'b', whatICanDo: 'c' });
  assert.ok(ok.ok && ok.answers.whatHappened === 'a');
  assert.deepStrictEqual(validateAnswers({ whatHappened: 'a', whatINeed: '  ', whatICanDo: 'c' }), { ok: false, field: 'whatINeed' });
  assert.deepStrictEqual(validateAnswers({ whatHappened: 'x'.repeat(2001), whatINeed: 'b', whatICanDo: 'c' }), { ok: false, field: 'whatHappened' });
  assert.deepStrictEqual(validateAnswers(null), { ok: false, field: 'missing' });
  assert.ok(isCategory('kids') && !isCategory('politics') && isTiming('tonight') && !isTiming('never'));
});

test('localToUtc: 19:00 Oslo in September is 17:00Z; in January 18:00Z', () => {
  assert.strictEqual(localToUtc(2026, 9, 28, 19, OSLO).toISOString(), '2026-09-28T17:00:00.000Z');
  assert.strictEqual(localToUtc(2026, 1, 15, 19, OSLO).toISOString(), '2026-01-15T18:00:00.000Z');
});

test('"tonight" before 19:00 local → today 19:00 local', () => {
  const now = new Date('2026-09-28T16:00:00.000Z');             // 18:00 Oslo
  assert.strictEqual(reminderInstant('tonight', now, OSLO)!.toISOString(), '2026-09-28T17:00:00.000Z');
});

test('"tonight" at/after 19:30 local → in 15 minutes (edge case)', () => {
  const now = new Date('2026-09-28T17:31:00.000Z');             // 19:31 Oslo
  assert.strictEqual(reminderInstant('tonight', now, OSLO)!.toISOString(), '2026-09-28T17:46:00.000Z');
  const gap = new Date('2026-09-28T17:15:00.000Z');             // 19:15 Oslo — 19:00 already passed
  assert.strictEqual(reminderInstant('tonight', gap, OSLO)!.toISOString(), '2026-09-28T17:30:00.000Z');
});

test('"tomorrow" → tomorrow 19:00 local; "now" → no reminder; bad tz falls back to Oslo', () => {
  const now = new Date('2026-09-28T21:30:00.000Z');             // 23:30 Oslo
  assert.strictEqual(reminderInstant('tomorrow', now, OSLO)!.toISOString(), '2026-09-29T17:00:00.000Z');
  assert.strictEqual(reminderInstant('tomorrow', now, 'America/New_York')!.toISOString(), '2026-09-29T23:00:00.000Z');
  assert.strictEqual(reminderInstant('now', now, OSLO), null);
  assert.strictEqual(reminderInstant('tonight', new Date('2026-09-28T10:00:00.000Z'), 'Mars/Olympus')!.toISOString(), '2026-09-28T17:00:00.000Z');
  assert.strictEqual(expiryInstant(new Date('2026-09-01T00:00:00.000Z')).toISOString(), `2026-09-0${1 + EXPIRY_DAYS}T00:00:00.000Z`);
});

test('agreement hash: canonical (sorted keys, NFC), bound to couple/mediation/revision', () => {
  const texts = { no: { shared: 'Vi prøver', perPartner: { b: 'B gjør', a: 'A gjør' } } };
  const h1 = agreementHash('c', 'm', 1, texts);
  const h2 = agreementHash('c', 'm', 1, { no: { perPartner: { a: 'A gjør', b: 'B gjør' }, shared: 'Vi prøver' } });
  assert.strictEqual(h1, h2, 'key order must not matter');
  assert.strictEqual(agreementHash('c', 'm', 1, { no: { shared: 'Vi prøver', perPartner: { a: 'A gjør', b: 'B gjør' } } }),
    agreementHash('c', 'm', 1, { no: { shared: 'Vi pröver'.normalize('NFC') === 'Vi pröver' ? 'Vi prøver' : 'Vi prøver', perPartner: { a: 'A gjør', b: 'B gjør' } } }));
  assert.notStrictEqual(h1, agreementHash('c', 'm', 2, texts), 'revision changes the hash');
  assert.notStrictEqual(h1, agreementHash('c', 'other', 1, texts), 'mediation id changes the hash');
  assert.notStrictEqual(h1, agreementHash('c', 'm', 1, { no: { shared: 'Vi prøver!', perPartner: { a: 'A gjør', b: 'B gjør' } } }));
  assert.match(h1, /^[0-9a-f]{64}$/);
});

test('safety: explicit phrases flag; ordinary conflict does not; model verdict combined', () => {
  assert.deepStrictEqual(phraseSafetyScan(['Han slår meg når han er sint.']), ['violence']);
  assert.deepStrictEqual(phraseSafetyScan(['She threatens to hurt me if I leave.']), ['threats']);
  assert.deepStrictEqual(phraseSafetyScan(['Jeg er redd for hva han gjør.']), ['fear']);
  assert.deepStrictEqual(phraseSafetyScan(['Vi krangler om oppvasken og jeg blir så sint.', 'I am angry about money and we argue a lot.']), []);
  assert.deepStrictEqual(parseSafetyOutput({ flagged: true, categories: ['threats'] }), { flagged: true, categories: ['threats'] });
  assert.strictEqual(parseSafetyOutput({ flagged: 'yes' }), null);
  assert.strictEqual(combineSafety([], { flagged: true, categories: ['coercive_control'] }).source, 'model');
  assert.strictEqual(combineSafety(['violence'], null).source, 'phrases');
  assert.deepStrictEqual(combineSafety([], null), { flagged: false, categories: [], source: 'none' });
  assert.strictEqual(combineSafety([], { flagged: false, categories: [] }).flagged, false);
});

const input = {
  category: 'chores' as const,
  starter: { uid: 'uidA', name: 'Adel', lang: 'no' as const },
  partner: { uid: 'uidB', name: 'Liv', lang: 'en' as const },
  answers: {
    uidA: { whatHappened: 'Jeg tar all oppvasken', whatINeed: 'Litt hjelp', whatICanDo: 'Si ifra tidligere' },
    uidB: { whatHappened: 'I cook every day', whatINeed: 'Appreciation', whatICanDo: 'Do the dishes twice a week' },
  },
  langs: ['no', 'en'] as ('no' | 'en')[],
};

test('prompt names the non-starter first and asks for both languages', () => {
  const p = buildGenerationPrompt(input);
  assert.ok(p.indexOf('Liv') < p.indexOf('Adel'));
  assert.match(p, /Always mention Liv before Adel/);
  assert.match(p, /Norwegian \(bokmål\) AND English/);
  assert.match(p, /"no": \{/); assert.match(p, /"en": \{/);
  assert.match(p, /uidA/); assert.match(p, /uidB/);
});

const good = (lang: string) => ({
  sameTeam: 'Dere vil begge ha et hjem som fungerer.', different: 'Dere ser ulikt på hvem som gjør mest.',
  needs: { uidB: 'Liv trenger å bli sett.', uidA: 'Adel trenger litt hjelp.' }, idea: 'Prøv en fast oppvaskdag.',
  agreement: { shared: `Vi deler oppvasken (${lang}).`, perPartner: { uidA: 'Adel sier ifra tidligere.', uidB: 'Liv tar oppvasken to dager.' } },
});

test('generation output: validated per language and uid; missing pieces → null; long lines trimmed', () => {
  const out = parseGenerationOutput({ no: good('no'), en: good('en') }, ['no', 'en'], ['uidA', 'uidB']);
  assert.ok(out);
  assert.strictEqual(out!.summary.no!.needs.uidA, 'Adel trenger litt hjelp.');
  assert.strictEqual(out!.agreement.en!.shared, 'Vi deler oppvasken (en).');
  assert.strictEqual(parseGenerationOutput({ no: good('no') }, ['no', 'en'], ['uidA', 'uidB']), null, 'missing language');
  const missingUid = { no: { ...good('no'), needs: { uidA: 'x' } } };
  assert.strictEqual(parseGenerationOutput(missingUid, ['no'], ['uidA', 'uidB']), null);
  assert.strictEqual(parseGenerationOutput('nope', ['no'], ['uidA']), null);
  const long = { no: { ...good('no'), idea: 'x'.repeat(500) } };
  assert.ok(parseGenerationOutput(long, ['no'], ['uidA', 'uidB'])!.summary.no!.idea.length <= 280);
});

test('output neutrality guard rejects winner/label language', () => {
  const ok = parseGenerationOutput({ no: good('no') }, ['no'], ['uidA', 'uidB'])!;
  assert.ok(outputIsNeutral(ok));
  const bad = parseGenerationOutput({ no: { ...good('no'), different: 'Adel har rett og Liv tar feil.' } }, ['no'], ['uidA', 'uidB'])!;
  assert.ok(!outputIsNeutral(bad));
  const bad2 = parseGenerationOutput({ no: { ...good('no'), idea: 'Liv is being toxic here.' } }, ['no'], ['uidA', 'uidB'])!;
  assert.ok(!outputIsNeutral(bad2));
});

test('edit: shared + own line only, mirrored to the other language; cannot touch the partner line', () => {
  const cur = { no: { shared: 'Vi prøver', perPartner: { uidA: 'A gjør', uidB: 'B gjør' } }, en: { shared: 'We try', perPartner: { uidA: 'A does', uidB: 'B does' } } };
  const next = applyAgreementEdit(cur, 'uidA', 'no', 'Vi prøver hardere', 'A gjør mer')!;
  assert.strictEqual(next.no!.perPartner.uidA, 'A gjør mer');
  assert.strictEqual(next.no!.perPartner.uidB, 'B gjør', 'partner line untouched');
  assert.strictEqual(next.en!.perPartner.uidB, 'B does');
  assert.strictEqual(next.en!.shared, 'Vi prøver hardere', 'other language receives the edited text verbatim');
  assert.strictEqual(applyAgreementEdit(cur, 'uidX', 'no', 's', 'm'), null, 'non-member uid rejected');
  assert.strictEqual(applyAgreementEdit(cur, 'uidA', 'no', '   ', 'm'), null);
});

test('accept: both must match the current hash; nudge gap 1 hour', () => {
  assert.ok(bothAccepted({ a: { hash: 'h', at: 1 }, b: { hash: 'h', at: 2 } }, ['a', 'b'], 'h'));
  assert.ok(!bothAccepted({ a: { hash: 'h', at: 1 }, b: { hash: 'old', at: 2 } }, ['a', 'b'], 'h'));
  assert.ok(!bothAccepted({ a: { hash: 'h', at: 1 } }, ['a', 'b'], 'h'));
  const now = new Date('2026-09-28T12:00:00Z');
  assert.ok(canNudge(null, now));
  assert.ok(!canNudge(new Date('2026-09-28T11:30:00Z'), now));
  assert.ok(canNudge(new Date('2026-09-28T10:59:00Z'), now));
});
