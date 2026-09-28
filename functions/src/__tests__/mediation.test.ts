// Pure mediation logic. Run: npm test
import { test } from 'node:test';
import * as assert from 'node:assert';
import {
  validateTopic, validateAnswer, validateFeedback, reminderInstant, localToUtc, expiryInstant, agreementHash, phraseSafetyScan,
  parseSafetyOutput, combineSafety, repeatsVerbatim, textIsNeutral, buildInvitationPrompt, parseInvitationOutput,
  buildRound1Prompt, parseRoundOutput, buildRevisionPrompt, parseRevisionOutput, agreementFromProposal,
  applyAgreementEdit, bothAccepted, canNudge, isCategory, isTiming, EXPIRY_DAYS, UNRESOLVED_NOTE,
} from '../mediation';

const OSLO = 'Europe/Oslo';

test('private inputs: kind-tagged, trimmed, bounded; feedback choice restricted', () => {
  assert.deepStrictEqual(validateTopic({ kind: 'topic', topic: ' telefonen  ved bordet ', wish: 'mer ro' }), { topic: 'telefonen ved bordet', wish: 'mer ro' });
  assert.strictEqual(validateTopic({ topic: 'a', wish: 'b' }), null, 'kind required');
  assert.strictEqual(validateTopic({ kind: 'topic', topic: 'a', wish: '   ' }), null);
  assert.strictEqual(validateTopic({ kind: 'topic', topic: 'x'.repeat(1001), wish: 'b' }), null);
  assert.strictEqual(validateTopic(null), null);
  assert.deepStrictEqual(validateAnswer({ kind: 'answer', view: 'v', need: 'n' }), { view: 'v', need: 'n' });
  assert.strictEqual(validateAnswer({ kind: 'topic', view: 'v', need: 'n' }), null, 'wrong kind');
  assert.deepStrictEqual(validateFeedback({ kind: 'feedback', feedback: 'happy' }), { feedback: 'happy', addition: '' }, 'addition optional');
  assert.deepStrictEqual(validateFeedback({ kind: 'feedback', feedback: 'almost', addition: ' litt tidligere ' }), { feedback: 'almost', addition: 'litt tidligere' });
  assert.strictEqual(validateFeedback({ kind: 'feedback', feedback: 'no' }), null);
  assert.strictEqual(validateFeedback({ kind: 'feedback', feedback: 'almost', addition: 'x'.repeat(301) }), null);
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

const adel = { uid: 'uidA', name: 'Adel', lang: 'no' as const };
const liv = { uid: 'uidB', name: 'Liv', lang: 'en' as const };
const RAW_TOPIC = 'Jeg blir sliten av at telefonen alltid er framme når vi spiser middag sammen på kveldene.';
const RAW_WISH = 'At vi legger bort telefonen under middagen og faktisk snakker sammen.';

test('verbatim guard: 5+ consecutive words from the raw input is a copy; topic words alone are fine', () => {
  const raws = [RAW_TOPIC, RAW_WISH];
  // Realistic neutral rewrites that reuse the topic words MUST pass.
  assert.ok(!repeatsVerbatim('Adel vil gjerne snakke om telefonen ved middagsbordet.', raws));
  assert.ok(!repeatsVerbatim('Dere ønsker begge mer ro rundt husarbeid og telefonen.', raws));
  assert.ok(!repeatsVerbatim('Liv og Adel vil ha roligere kvelder – kveldene er viktige for dere begge.', raws));
  assert.ok(!repeatsVerbatim('Dere vil legge bort telefonen når dere spiser.', raws), 'four shared words in a row is still allowed');
  // A copied sentence fragment (5+ words, punctuation/case ignored) is rejected.
  assert.ok(repeatsVerbatim('Det er slitsomt at TELEFONEN alltid er framme når vi spiser.', raws));
  assert.ok(repeatsVerbatim('Ønsket er: "at vi legger bort telefonen under middagen".', raws));
  assert.ok(!repeatsVerbatim('kort', raws));
});

test('invitation prompt: second person to the partner, both languages, rephrase hint; output guarded', () => {
  const p = buildInvitationPrompt({ category: 'communication', initiator: adel, partner: liv, topic: RAW_TOPIC, wish: RAW_WISH, langs: ['no', 'en'], rephrase: 0 });
  assert.match(p, /addressed to Liv/); assert.match(p, /Norwegian \(bokmål\) AND English/); assert.doesNotMatch(p, /rephrase #/);
  assert.match(buildInvitationPrompt({ category: 'communication', initiator: adel, partner: liv, topic: 't', wish: 'w', langs: ['no'], rephrase: 2 }), /rephrase #2/);
  const ok = parseInvitationOutput({ no: 'Hei Liv – jeg vil gjerne snakke om telefonen ved middagen. Håper vi kan finne mer ro sammen.', en: 'Hi Liv – I would like to talk about phones at dinner. Hoping for calmer evenings together.' }, ['no', 'en'], [RAW_TOPIC, RAW_WISH]);
  assert.ok(ok && ok.no && ok.en);
  assert.strictEqual(parseInvitationOutput({ no: 'bare norsk' }, ['no', 'en'], []), null, 'missing language');
  assert.strictEqual(parseInvitationOutput({ no: 'Du har alltid telefonen framme.' }, ['no'], []), null, 'absolutes rejected');
  assert.strictEqual(parseInvitationOutput({ no: `Adel sa: ${RAW_TOPIC}` }, ['no'], [RAW_TOPIC, RAW_WISH]), null, 'verbatim copy rejected');
  assert.ok(parseInvitationOutput({ no: 'x'.repeat(500) }, ['no'], [])!.no!.length <= 280, 'long line trimmed');
});

test('round-1 prompt carries BOTH perspectives (initiator topic+wish, partner view+need), partner named first', () => {
  const p = buildRound1Prompt({ category: 'chores', initiator: adel, partner: liv, invitation: 'inv', topic: RAW_TOPIC, wish: RAW_WISH, view: 'Jeg trenger pausen', need: 'litt tid alene', langs: ['no', 'en'] });
  const partnersLine = p.split('\n').find((l) => l.startsWith('Two partners:'))!;
  assert.ok(partnersLine.indexOf('Liv') < partnersLine.indexOf('Adel'));
  assert.match(p, /Always mention Liv before Adel/);
  assert.match(p, /Liv — how they see it: Jeg trenger pausen \| what they need: litt tid alene/);
  assert.match(p, new RegExp(`Adel — what they wanted to bring up: ${RAW_TOPIC.slice(0, 20)}`));
  assert.match(p, /"no": \{/); assert.match(p, /"en": \{/); assert.match(p, /uidA/); assert.match(p, /uidB/);
});

const round = () => ({
  sameTeam: 'Dere vil begge ha rolige middager.', different: 'Dere ser ulikt på hvor ofte telefonen er framme.',
  needs: { uidB: 'Liv trenger en pause etter jobb.', uidA: 'Adel trenger oppmerksomhet ved bordet.' }, proposal: 'Prøv telefonfri middag tre kvelder denne uka.',
});

test('round output: validated per language and uid; neutrality; long lines trimmed', () => {
  const out = parseRoundOutput({ no: round(), en: round() }, ['no', 'en'], ['uidB', 'uidA']);
  assert.ok(out);
  assert.strictEqual(out!.no!.needs.uidA, 'Adel trenger oppmerksomhet ved bordet.');
  assert.strictEqual(parseRoundOutput({ no: round() }, ['no', 'en'], ['uidB', 'uidA']), null, 'missing language');
  assert.strictEqual(parseRoundOutput({ no: { ...round(), needs: { uidA: 'x' } } }, ['no'], ['uidB', 'uidA']), null, 'missing uid');
  assert.strictEqual(parseRoundOutput({ no: { ...round(), different: 'Adel har rett og Liv tar feil.' } }, ['no'], ['uidB', 'uidA']), null);
  assert.strictEqual(parseRoundOutput({ no: { ...round(), proposal: 'Liv is being toxic here.' } }, ['no'], ['uidB', 'uidA']), null);
  assert.strictEqual(parseRoundOutput('nope', ['no'], ['uidA']), null);
  assert.ok(parseRoundOutput({ no: { ...round(), proposal: 'x'.repeat(500) } }, ['no'], ['uidB', 'uidA'])!.no!.proposal.length <= 280);
  assert.ok(textIsNeutral('Dere vil begge ha ro.') && !textIsNeutral('Du gjør aldri noe.'));
});

test('revision prompt: private feedback without names as authors of the change; output guarded against copying additions', () => {
  const p = buildRevisionPrompt({ round: 2, langs: ['no'], partnerFirst: liv, initiator: adel, previous: { no: round() }, feedback: { uidB: { feedback: 'happy', addition: '' }, uidA: { feedback: 'almost', addition: 'heller to kvelder enn tre' } } });
  assert.match(p, /Round 2 of at most 3/); assert.match(p, /Liv: happy/); assert.match(p, /Adel: almost — wants a tweak: heller to kvelder enn tre/);
  assert.match(p, /without attributing it to a person/);
  const ok = parseRevisionOutput({ no: { proposal: 'Prøv telefonfri middag to kvelder denne uka.', whatChanged: 'Antall kvelder ble justert ned.' } }, ['no'], ['heller to kvelder enn tre']);
  assert.ok(ok && ok.no);
  assert.strictEqual(parseRevisionOutput({ no: { proposal: 'ok', whatChanged: 'Adel ville heller ha to kvelder enn tre kvelder.' } }, ['no'], ['jeg vil heller ha to kvelder enn tre kvelder']), null, 'copied addition rejected');
  assert.strictEqual(parseRevisionOutput({ no: { proposal: 'ok' } }, ['no'], []), null, 'whatChanged required');
});

test('agreement from an accepted proposal: shared = proposal, neutral per-partner lines, per language; unresolved note in both languages', () => {
  const a = agreementFromProposal({ no: 'Telefonfri middag.', en: 'Phone-free dinner.' }, ['uidB', 'uidA']);
  assert.strictEqual(a.no!.shared, 'Telefonfri middag.');
  assert.deepStrictEqual(a.en!.perPartner, { uidB: 'Tries the suggestion this week.', uidA: 'Tries the suggestion this week.' });
  assert.ok(UNRESOLVED_NOTE.no.length > 0 && UNRESOLVED_NOTE.en.length > 0 && textIsNeutral(UNRESOLVED_NOTE.no) && textIsNeutral(UNRESOLVED_NOTE.en));
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
