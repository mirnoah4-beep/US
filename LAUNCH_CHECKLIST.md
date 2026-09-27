# Launch Checklist

## Release candidate hygiene
- [ ] Decide the remaining local dark-theme changes before the release build: either commit them as a separate reviewed feature, or stash/discard them.
- [ ] Build the release candidate from a clean `origin/main` working tree — do not ship an APK/AAB that accidentally includes local uncommitted theme work.
- [ ] Run the full release gates on the exact tree used for the store build:
  - [ ] `npm test`
  - [ ] `npm run build`
  - [ ] `npm run test:rules`
  - [ ] `flutter analyze`
  - [ ] `flutter test`
- [ ] Confirm no temporary diagnostic/probe/isolation code or test-only rules remain.
- [ ] Confirm the final `pubspec.yaml` version/build number is intentional.

## Final two-phone smoke test
- [ ] Pair two real users and verify both accounts see the same active couple.
- [ ] Text chat works both directions.
- [ ] Chat push opens the correct conversation.
- [ ] Unread badge increments and clears correctly.
- [ ] `Sendt/Sent → Sett/Seen` updates correctly.
- [ ] Typing indicator appears live, expires when stale, and stops on background/leave.
- [ ] Heart reaction add/remove syncs to the partner.
- [ ] Gallery image sends, arrives, opens fullscreen, and remains inaccessible to outsiders.
- [ ] Camera image sends successfully.
- [ ] Airplane-mode/reconnect behaviour is sane for queued text and image retry.
- [ ] Idea → chat sharing still opens the relevant idea.
- [ ] Quick replies work and `Planlegg noe` opens Plan.
- [ ] Memories navigation still works.
- [ ] Smart reminders / relationship notifications still work.
- [ ] Logout/login preserves the correct account/couple state.
- [ ] Partner disconnect removes former-partner access immediately.
- [ ] Account deletion / couple dissolve behaviour is verified, including what happens to historic chat images in Storage.

## Security
- [ ] Re-enable App Check with AndroidProvider.playIntegrity + AppleProvider.appleAttest
- [ ] Set Firestore + Storage to "Enforced" in Firebase Console → App Check → APIs
- [ ] Before any Storage-rules release that uses `firestore.get()/exists()`, verify the Firebase Storage service agent still has `roles/firebaserules.firestoreServiceAgent`.
- [ ] Deploy Firestore-backed Storage rules interactively when IAM validation/granting is required. See `docs/FIREBASE_STORAGE_RULES.md`.

## Legal
- [x] Privacy policy URL published — https://us-app-4bf30.web.app/privacy.html (+ /terms.html), source in `hosting/`, deploy with `firebase deploy --only hosting`
- [x] GDPR consent on signup (EU users) — "Ved å fortsette godtar du…" on login screen now links to live terms + privacy policy
- [x] Delete account functionality — Settings → Delete account (callable `deleteAccount`)

## Technical
- [x] Release keystore configured (not debug)
- [x] `flutter build appbundle --release` tested and working
- [ ] No crashes in Crashlytics (all launch-blocking issues resolved)
- [ ] All test/debug code removed (print statements, test buttons, hardcoded diagnostic data)
- [ ] App Check re-enabled (see Security above)
- [ ] FCM push notifications tested on real devices
- [ ] All Firestore indexes deployed
- [ ] Storage rules tested in emulator AND one Firestore-backed Storage rule smoke-tested on a real device
- [ ] Billing/payment method healthy and budget alerts configured
- [ ] No temporary Cloud Functions are deployed

## Data lifecycle
Final behaviour (implemented in `functions/src/coupleLifecycle.ts` + `storageCleanup.ts`, tested in `functions/src/__rules__/lifecycle.emulator.test.ts`):
- [x] **Disconnect** (`disconnectPartner` → `dissolveCouple`) deletes the couple's Firestore data (couple doc + every subcollection: messages, chat state, memories, plans, settings …) **and all couple Storage under `couples/{coupleId}/`** (chat images and memories are permanently deleted, not just made inaccessible). Members are unlinked and the invite removed.
- [x] **Account deletion** (`deleteAccount`) does the same for the couple and additionally deletes **`users/{uid}/`** in Storage and the user document, then the Auth user last.
- [x] **Former partner immediately loses access**: every Firestore and Storage rule resolves membership through the couple document, which is deleted — reads, writes and new uploads into the old prefix are denied from that moment.
- [x] Cleanup is **idempotent and server-authoritative** (Admin SDK only; the client has no broad delete permission). Prefixes are built server-side from validated ids (never client paths), deleted with `force: true`, paginated, empty prefixes are a no-op, repeated runs are safe. Counts and error codes are logged — never file names or contents; residual failures surface as `deleteAccount` warnings / error logs instead of being swallowed.
- [x] Safety net: `onCoupleDeleted` (Firestore trigger on `couples/{coupleId}`) re-runs the same helper after the document is gone, so a couple removed by any other route never leaves files behind. `dissolveCouple` remains the primary path.
- [x] Orphaned chat images (upload succeeded, message write failed): the retry keeps the same id/path, detects the existing object and completes only the Firestore message — no overwrite, no client delete. Objects from a *never*-retried failure stay under the couple prefix until dissolve/delete removes them.
- [ ] Confirm the privacy wording says: leaving a couple or deleting an account permanently deletes the shared chat, chat images and memories for **both** partners.

## App Store / Play Store
- [ ] App icon (all sizes)
- [ ] Screenshots (phone + tablet, NO + EN)
- [ ] Store description (NO + EN)
- [ ] Version number set in `pubspec.yaml`
- [ ] Content rating completed
- [ ] iOS: Apple Developer account ($99/year)
- [ ] Android: Google Play Developer account ($25 one-time)

## iOS specific (when ready)
- [ ] iOS port tested on real iPhone
- [ ] Sign in with Apple implemented
- [ ] Push notifications via APNs configured
- [ ] App Store review guidelines checked
