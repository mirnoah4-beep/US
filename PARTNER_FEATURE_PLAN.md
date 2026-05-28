# "Vårt forhold" / "Our relationship" — Feature Plan

Screen: `lib/screens/our_relationship_screen.dart`  
Entry: tapping the couple card in Settings → OurRelationshipScreen

---

## LAYOUT (top to bottom)

1. Header: back button + "Vårt forhold" / "Our relationship"
2. Avatar row: both 76px circles, slightly overlapping, white border, small heart badge centered between them
3. Names: "Noah & Adel" (bold, centered)
4. Anniversary card (white, rounded, shadow):
   - When date IS set:
     - "Sammen siden 12. mai 2020" (small label)
     - Horizontal timer row: `[6] : [00] : [16] : [47]` / `år  mnd  dager  sek`
     - Numbers ~26px bold, unit labels 11px muted, colons muted
     - Computed once on page load (NOT live-ticking)
     - "Endre jubileumsdato" outlined button with calendar icon
   - When date NOT set:
     - Heart icon + "Sett en dato" prompt
     - "Foreslå en dato" button
5. Disconnect card (red/destructive)

---

## DATA  (`couples/{coupleId}` fields)

| Field                     | Type                            | Notes                      |
|---------------------------|---------------------------------|----------------------------|
| `togetherSince`           | `Timestamp \| null`             | Confirmed anniversary date |
| `togetherSinceProposal`   | `{date: Timestamp, proposedBy: uid} \| null` | Pending proposal |
| `disconnectRequestedBy`   | `uid \| null`                   | Pending disconnect request |

These are already wired into `AppState._subscribeCouple` (Step 1 done).

---

## BUILD ORDER

### ✅ Step 1 — Layout + timer (complete)
- Page layout with overlapping avatars + heart
- Timer row with computed duration
- Placeholder date when `togetherSince` is null
- Non-functional "Endre jubileumsdato" / "Foreslå en dato" button stubs
- Instant disconnect (existing flow, replaced in Step 3)

### Step 2 — Anniversary propose → approve + Firestore rules
- Either partner taps "Foreslå en dato" / "Endre jubileumsdato"
- Date picker → writes `togetherSinceProposal: {date, proposedBy}` to couple doc
- Other partner sees banner: "$name foreslår [date]" with Approve / Decline
- Approve → writes `togetherSince`, clears `togetherSinceProposal`
- Decline → clears `togetherSinceProposal`
- Firestore rules: only allow writing `togetherSince` / `togetherSinceProposal` if uid in members

### Step 3 — Disconnect request → approve + Firestore rules
- Requester taps disconnect → writes `disconnectRequestedBy: uid`
  (does NOT disconnect yet)
- Other partner sees: "$name ønsker å koble fra" with Confirm / Cancel
- Confirm → runs existing `disconnectCouple` transaction + clears field
- Requester can cancel their own request → clears `disconnectRequestedBy`
- Firestore rules: only a member can write `disconnectRequestedBy`;
  only a member can clear it (approve or cancel)

---

## FIRESTORE RULES (Steps 2 + 3)

Existing: `couples/{coupleId}` update allowed for all members.  
No new rule changes needed — all writes are by members (already allowed).  
The couple doc rule covers subcollection writes too.

**Safe confirmation**: the existing rule `request.auth.uid in resource.data.members` 
covers all new field writes since proposing, approving, and requesting disconnect 
are all done by authenticated members of the couple. No rule changes required 
for Steps 2 or 3.

---

## STRINGS (lib/l10n/strings.dart)

All added under `// ── Our Relationship Screen ──` section.  
Both Steps 2 and 3 strings pre-added to avoid revisiting the file.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `lib/l10n/strings.dart` | New strings for all steps |
| `lib/models/app_state.dart` | New fields + stream updates (Step 1 done) |
| `lib/screens/our_relationship_screen.dart` | Full redesign + flows |
| `lib/services/firestore_service.dart` | Step 2: proposeAnniversary, approveAnniversary, declineAnniversary; Step 3: requestDisconnect, approveDisconnect, cancelDisconnectRequest |
| `firestore.rules` | No changes needed (members rule covers all new fields) |
