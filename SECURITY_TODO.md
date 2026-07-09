# Security TODO — H1: Enforce App Check

> **Status:** deferred until after the current release. Everything else from the
> audit (C1, H2, H3, H4, H5, H6, H7) is applied and deployed. This file is the
> pick-up plan for H1 in a fresh session.

## Context / current state

App Check is **activated on the client but enforced nowhere**, so it currently
provides zero protection — every rule/function that trusts `request.auth`
is reachable from any scripted client with a self-serve token.

- Client already calls `FirebaseAppCheck.instance.activate(...)` in
  `lib/main.dart` (~line 43) with:
  - `AndroidProvider.debug` / `AppleProvider.debug` when `kDebugMode`
  - `AndroidProvider.playIntegrity` / `AppleProvider.appAttest` in release
- Verified enforcement status (Firebase App Check REST API, project
  `us-app-4bf30`) — **all UNENFORCED**:
  - `firestore.googleapis.com` → UNENFORCED
  - `firebasestorage.googleapis.com` → UNENFORCED
  - `identitytoolkit.googleapis.com` (Auth) → UNENFORCED
  - `oauth2.googleapis.com` → UNENFORCED
  - (Callable Functions enforcement is **code-based**, not a console service —
    see below.)

**Callable functions to protect** (the exposed server surface), all in
`functions/src/index.ts`, region `europe-west1`:
`createInvite`, `deleteAccount`, `generateWeeklyIdeasNow`, `callOpenAI`.
The Firestore/Storage triggers (`onDocument*`, `onSchedule`) are **not**
client-invocable and take no App Check token — leave them alone.

## ⚠️ Golden rule: register debug tokens + confirm metrics BEFORE enforcing

Enforcing before real traffic is verified will **lock out live users**. The app
already ships `activate()`, so released builds *should* be sending tokens — but
that must be proven via the App Check metrics dashboard (Verified vs Unverified)
before flipping any enforcement on. Enforce only when a service shows
~100% verified for legit traffic.

---

## Step 1 — Register debug tokens (so dev builds keep working)

Debug builds use the *debug* provider, which mints a random token that must be
allow-listed once per install/device.

### Android (debug build)
1. Run the app in debug (`flutter run`).
2. In the logs (`adb logcat` / IDE console) find a line like:
   `DebugAppCheckProvider: Enter this debug secret into the allow list...`
   followed by a UUID (the debug token).
3. Firebase Console → **App Check** → **Apps** → select the **Android** app →
   ⋮ / **Manage debug tokens** → **Add debug token** → paste the UUID → name it
   (e.g. "Noah Pixel debug") → Save.

### iOS (debug build, simulator or device)
1. Run in debug from Xcode (or `flutter run` on iOS).
2. In the Xcode console find:
   `Firebase App Check Debug Token: <UUID>`
   (If it doesn't print, add launch arg `-FIRDebugEnabled`, or set env
   `FIRAAppCheckDebugToken` — but the printed-token flow is easiest.)
3. Firebase Console → App Check → Apps → select the **iOS** app → Manage debug
   tokens → Add → paste → Save.

Notes:
- Each device/install/CI runner has its **own** debug token — register each.
- Debug tokens are secrets; don't commit them. Rotate/delete when a device is
  retired.
- CI: if integration tests hit real Firebase, register the CI runner's token
  too (or point CI at the emulator suite, which bypasses App Check).

### Web (only if you actually ship the `web/` target)
`activate()` currently sets Android/Apple providers only — **no web provider**.
If web is a real target you must add a reCAPTCHA (v3 or Enterprise) provider on
web *and* register a debug token for local web dev, otherwise enforcing
Firestore/Storage will break the web app. If web is not shipped, ignore.

---

## Step 2 — Add `enforceAppCheck: true` to the callables (code-based)

Callable-function enforcement is **not** a console toggle — set it in code and
redeploy. Rollback = redeploy without the flag.

### Diffs — `functions/src/index.ts`

```diff
@@ generateWeeklyIdeasNow @@
-export const generateWeeklyIdeasNow = onCall(
-  { region: 'europe-west1' },
+export const generateWeeklyIdeasNow = onCall(
+  { region: 'europe-west1', enforceAppCheck: true },
   async (request) => {
```

```diff
@@ deleteAccount @@
-export const deleteAccount = onCall(
-  { region: 'europe-west1' },
+export const deleteAccount = onCall(
+  { region: 'europe-west1', enforceAppCheck: true },
   async (request) => {
```

```diff
@@ createInvite @@
-export const createInvite = onCall(
-  { region: 'europe-west1' },
+export const createInvite = onCall(
+  { region: 'europe-west1', enforceAppCheck: true },
   async (request) => {
```

```diff
@@ callOpenAI @@
-export const callOpenAI = onCall(
-  { region: 'europe-west1', secrets: ['OPENAI_API_KEY'] },
+export const callOpenAI = onCall(
+  { region: 'europe-west1', secrets: ['OPENAI_API_KEY'], enforceAppCheck: true },
   async (request) => {
```

Then:
```bash
cd functions && npx tsc --noEmit          # expect exit 0
firebase deploy --only functions
```

With `enforceAppCheck: true`, a request without a valid App Check token is
rejected by the SDK before your handler runs (the client sees
`unauthenticated`/`failed-precondition`). Optional: also consider replay
protection (`consumeAppCheckToken`) later for the most sensitive calls — not
required for H1.

---

## Step 3 — Console toggles for Firestore & Storage (in this order)

Do this **after** Step 1 (tokens registered) and **after** watching metrics.
For each service: Firebase Console → **App Check** → **APIs** tab → pick the
service → review the **Verified / Unverified requests** graph → only then
**Enforce**.

Recommended order (lowest blast radius / easiest recovery first):

1. **Functions** (already done in Step 2 via code) — smallest surface, per-function
   rollback by redeploy. Verify the 4 callables still work from a debug build
   (with its token registered) and from a release/TestFlight build.
2. **Storage** — enforce next. Test: avatar upload, memory image upload/view,
   idea images. Watch metrics 1–3 days first.
3. **Firestore** — enforce **last**. Highest traffic and worst blast radius
   (the whole app reads/writes it constantly), so give it the longest
   monitoring window and enforce only when Unverified is ~0 for real traffic.

Leave **Authentication** (`identitytoolkit`) and `oauth2` unenforced unless you
have a specific reason and have tested sign-in flows against it — enforcing Auth
App Check can interfere with sign-in on misconfigured clients.

---

## Step 4 — Verify, then rollback plan

**Verify after each enforcement:**
- Fresh install (release build) can: sign in, generate an invite code
  (`createInvite`), join with a code (`joinByCode` reads), upload/view images,
  run the AI features (`callOpenAI`), delete account (`deleteAccount`).
- Debug build with a registered token can do the same.
- App Check metrics show requests as Verified.

**Rollback (fast):**
- Firestore/Storage: Console → App Check → APIs → set back to **Unenforced**
  (takes effect within ~minutes).
- Functions: redeploy with `enforceAppCheck` removed (or set to `false`).

**Gotchas:**
- Old app versions that predate `activate()` would be blocked — current release
  ships `activate()`, so this is fine, but confirm via metrics before enforcing.
- Play Integrity requires the app be distributed via Play (or a registered
  test track); sideloaded release APKs may fail attestation — use a debug token
  for those, or test via internal testing track.
- iOS App Attest requires a real device (not simulator) for the production
  provider; simulator uses the debug provider + token.

---

## Quick checklist

- [ ] Register Android debug token(s)
- [ ] Register iOS debug token(s)
- [ ] (If web shipped) add reCAPTCHA provider + web debug token
- [ ] Add `enforceAppCheck: true` to the 4 callables, `tsc`, deploy
- [ ] Watch App Check metrics until Verified ≈ 100% for real traffic
- [ ] Enforce Functions (verify) → Storage (verify) → Firestore (verify)
- [ ] Keep Auth/oauth2 unenforced unless separately tested
- [ ] Confirm full smoke test on release + debug builds
