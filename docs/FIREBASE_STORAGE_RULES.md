# Firebase Storage cross-service Rules — IAM runbook

This project uses Cloud Storage Security Rules that call Firestore through
`firestore.get()` / `firestore.exists()` to verify couple membership.

That works in production only when the **Firebase Storage service agent** has
the IAM role:

`roles/firebaserules.firestoreServiceAgent`

For project `us-app-4bf30` (project number `196627223703`), the service
agent currently used by this project is:

`service-196627223703@gcp-sa-firebasestorage.iam.gserviceaccount.com`

## Why this matters

If that IAM binding is missing, Storage requests protected by a Firestore
lookup can fail with `storage/unauthorized` / rules-style 403 responses even
when:

- Firebase Auth is valid
- the user really is a member of the couple
- the path, MIME type, and size are valid
- the same rules pass in the local emulator

The emulator does not reproduce this production IAM dependency.

This was the root cause of the real-device chat-image upload failure found
before launch.

## Safe deploy procedure

Whenever `storage.rules` contains or changes a rule that depends on
`firestore.get()` / `firestore.exists()`:

1. Confirm the Firebase target:
   `firebase use`
2. Confirm it is `us-app-4bf30`.
3. Run the Storage rules emulator tests.
4. Deploy Storage rules explicitly and interactively:
   `firebase deploy --only storage --project us-app-4bf30 --interactive`
5. Confirm the Firebase Storage service agent still has
   `roles/firebaserules.firestoreServiceAgent`.
6. Run a real-device smoke test for at least one Firestore-backed Storage rule
   such as couple chat images.
7. Never work around an IAM failure by opening the bucket or weakening
   membership checks.

## Symptoms to check first

If a Storage rule works in the emulator but fails on-device with
`storage/unauthorized`, verify these before redesigning authorization:

- active Firebase project and bucket
- authenticated UID
- path / filename
- MIME type and object size
- Firestore membership document shape
- App Check enforcement status
- Firebase Storage service-agent IAM binding

## Current chat-image policy

`couples/{coupleId}/chatImages/{messageId}.jpg`

- read: current members of that couple only
- create: current members only, valid image, size-limited, valid filename
- overwrite: denied
- client delete: denied
- Firestore image messages may reference only their own couple's
  `chatImages` path

Keep this policy closed to outsiders.
