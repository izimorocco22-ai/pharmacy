# iOS Push Notifications — remaining manual setup

The code side is done (see "What was fixed in code" at the bottom), and steps 1
and 2 are now complete. **Step 3 (the APNs key) is the remaining blocker — iOS
push cannot work until it is done.** It needs Apple Developer access, so it
cannot be done from the repo.

Firebase project: `ordogo-f823c` (project number `730591777899`)
Apple Team ID: `425VUQXQJ7`

---

## 1. Register the three iOS apps in Firebase  ✅ DONE

All three iOS apps are registered in Firebase. Bundle IDs match what Xcode
builds:

| App            | iOS bundle ID           |
| -------------- | ----------------------- |
| `patient_app`  | `com.ordogo.patient`    |
| `pharmacy_app` | `com.ordogo.pharmacy`   |
| `rider_app`    | `com.ordogo.riderApp`   |

Firebase Console → Project settings → *Your apps* → **Add app → iOS**, once per
bundle ID above.

## 2. Add each `GoogleService-Info.plist`  ✅ DONE (on this machine only)

Each app's plist is in place, verified against the bundle ID Xcode builds:

| File                                            | `BUNDLE_ID`             |
| ----------------------------------------------- | ----------------------- |
| `patient_app/ios/Runner/GoogleService-Info.plist`  | `com.ordogo.patient`    |
| `pharmacy_app/ios/Runner/GoogleService-Info.plist` | `com.ordogo.pharmacy`   |
| `rider_app/ios/Runner/GoogleService-Info.plist`    | `com.ordogo.riderApp`   |

The Xcode projects already reference this file (file reference + "Copy Bundle
Resources" build phase), so dropping it at that path is enough — no Xcode
changes needed.

> Until now this file had never existed in the repo. `FirebaseApp.configure()`
> in `AppDelegate.swift` cannot initialise without it, so the iOS builds were
> running with Firebase disabled — no FCM token was ever minted, which left the
> backend with nothing to send to. That is the primary reason iOS got no
> notifications while Android worked.

### ⚠️ These files are gitignored — they will not reach another machine

`.gitignore:99` ignores `GoogleService-Info.plist` (and `google-services.json`
on line 98). The Android configs are untracked for the same reason, so this is
a deliberate project convention, not an oversight.

**Consequence:** a fresh clone, another developer's machine, or a CI runner
will have none of these files, and iOS push silently breaks again exactly as
before. Pick one:

- **Commit them** (what most Flutter projects do — the `API_KEY` inside is a
  client identifier restricted by bundle ID, and it ships inside the IPA
  anyway, so it is not a secret):
  ```bash
  git add -f */ios/Runner/GoogleService-Info.plist */android/app/google-services.json
  ```
- **Or keep them out of git** and distribute all six config files (3 iOS + 3
  Android) to every build machine out-of-band, and inject them in CI.

Either is fine — but decide, because leaving it unaddressed is what caused
this bug.

## 3. Upload the APNs authentication key to Firebase

Without this, Firebase accepts your sends and silently drops them at the APNs
hop.

1. Apple Developer → Certificates, Identifiers & Profiles → **Keys** → `+`
2. Enable **Apple Push Notifications service (APNs)**, create, download the
   `.p8` (downloadable **once** — store it safely)
3. Firebase Console → Project settings → **Cloud Messaging** → under each iOS
   app → **APNs Authentication Key** → Upload, with:
   - the `.p8` file
   - **Key ID** (shown next to the key in the Apple portal)
   - **Team ID** `425VUQXQJ7`

One key covers all three apps — upload it under each of them.

## 4. Confirm the App ID has Push Notifications enabled

Apple Developer → Identifiers → each bundle ID → tick **Push Notifications**.
With Xcode automatic signing this usually happens on its own, but check it:
if the capability is off, the provisioning profile has no `aps-environment`
and the build will fail to sign against the entitlement.

## 5. Rebuild

`ios/Podfile.lock` is stale — it currently pins only the bare `Flutter` pod,
with no Firebase and no plugins, i.e. iOS was last built before any of this was
added. It regenerates automatically:

```bash
cd rider_app            # repeat for patient_app and pharmacy_app
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa
```

---

## Verifying it works

1. Run the app on a **physical device** (the simulator cannot receive remote
   push), accept the permission prompt, and log in.
2. Look for `[push] FCM token registered` in the device log. If instead you see:
   - `[push] Firebase init failed` → step 1/2 is incomplete.
   - `[push] no APNs token` → step 3/4, or permission was denied.
   - `[push] notification permission: AuthorizationStatus.denied` → the user
     declined; reset via Settings → the app → Notifications.
3. Check the user document in MongoDB actually has an `fcmToken`.
4. Send a test from Firebase Console → Cloud Messaging → *Send test message*,
   pasting that token.

## Also worth checking on the backend

`adminpanel` only initialises Firebase Admin when `FIREBASE_PROJECT_ID` is set.
Confirm these are present in the **production** environment, or nothing is sent
on any platform:

```
FIREBASE_PROJECT_ID
FIREBASE_CLIENT_EMAIL
FIREBASE_PRIVATE_KEY     # keep the \n escapes intact
```

If they are missing the logs show `Firebase not initialized, skipping push
notification`.

---

## What was fixed in code (already done)

- **APNs token race** — `getToken()` was called before iOS had an APNs token,
  which throws `apns-token-not-set`. The throw was swallowed by an empty
  `catch`, so the token silently never reached the backend. It now waits for
  the APNs token first.
- **Foreground messages on iOS** — `setForegroundNotificationPresentationOptions`
  was never called, so iOS dropped any notification arriving while the app was
  open. Now set.
- **`flutter_local_notifications` had no iOS config** — initialised with
  Android settings only, and `NotificationDetails` carried no iOS section, so
  every `show()` was a no-op on iOS. iOS now presents via FCM directly, so the
  local plugin is only used on Android (and no longer double-notifies).
- **Token refresh listener** was attached *after* the call that threw, so it
  never ran; it is now attached first and only once.
- **`aps-environment` was hardcoded to `development`** — release/TestFlight
  builds registered against the APNs sandbox while FCM sent to production, so
  pushes were discarded. Now driven by `APS_ENVIRONMENT`, set per build
  configuration (Debug → `development`, Release/Profile → `production`).
- **Backend had no `apns` block** — messages went at default priority with no
  sound, and no `apns-push-type`, which iOS 13+ rejects. Added, with
  `apns-priority: 10`.
- **Backend multicast sent non-string `data`** — FCM rejects the whole batch
  unless every data value is a string; it is now stringified, guarded on
  Firebase being initialised, and dead tokens are pruned.
