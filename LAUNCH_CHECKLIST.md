# Launch Checklist

## Security
- [ ] Re-enable App Check with AndroidProvider.playIntegrity + AppleProvider.appleAttest
- [ ] Set Firestore + Storage to "Enforced" in Firebase Console → App Check → APIs

## Legal
- [x] Privacy policy URL published — https://us-app-4bf30.web.app/privacy.html (+ /terms.html), source in `hosting/`, deploy with `firebase deploy --only hosting`
- [x] GDPR consent on signup (EU users) — "Ved å fortsette godtar du…" on login screen now links to live terms + privacy policy
- [x] Delete account functionality — Settings → Delete account (callable `deleteAccount`)

## Technical
- [x] Release keystore configured (not debug)
- [x] flutter build appbundle --release tested and working
- [ ] No crashes in Crashlytics (all issues resolved)
- [ ] All test/debug code removed (print statements, test buttons, hardcoded data)
- [ ] App Check re-enabled (see Security above)
- [ ] FCM push notifications tested on real devices
- [ ] All Firestore indexes deployed

## App Store / Play Store
- [ ] App icon (all sizes)
- [ ] Screenshots (phone + tablet, NO + EN)
- [ ] Store description (NO + EN)
- [ ] Version number set in pubspec.yaml
- [ ] Content rating completed
- [ ] iOS: Apple Developer account ($99/year)
- [ ] Android: Google Play Developer account ($25 one-time)

## iOS specific (when ready)
- [ ] iOS port tested on real iPhone
- [ ] Sign in with Apple implemented
- [ ] Push notifications via APNs configured
- [ ] App Store review guidelines checked
