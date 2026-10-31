<p align="center">
  <img src="web/icons/Icon-192.png" width="96" alt="us-together icon">
</p>

<h1 align="center">us-together</h1>

<p align="center">
  A shared photo journal for two, grown as a cherry-blossom stem.<br>
  <a href="https://ustogether.space">ustogether.space</a> ·
  <a href="https://github.com/hkhaNguyen/us-together/releases">Android APK</a>
</p>

Every photo and moment the two of you add sprouts on a branch of one stem,
newest at the top under the flower, oldest down by the pot. The interface is
in Vietnamese.

The live site and APK only open for the two people in this journal. Anyone
else who signs in is told their account isn't in the book. To use it
yourselves, run your own copy (see [Run your own](#run-your-own)).

## Features

- **The stem** – photos and moments alternate left and right along one
  stem, with month markers, from the flower down to the pot.
- **Loose photos** – each batch hangs as one polaroid stack with a shared
  title. Add more photos to a stack later, or pick its cover.
- **Moments (kỷ niệm)** – a dated story with photos and a cover, which each
  of you can answer with your own reflection.
- **Anniversaries** – a day counter, a countdown to the next one, and on
  the day itself a heart with confetti.
- **Xem từ đầu** – replays the journal: swipe up from the pot to regrow the
  stem branch by branch, ending on the day count.
- **Trash** – deleted things wait 30 days and either of you can restore
  them.
- **Photos** – capture dates come from EXIF, files are compressed on the
  device (WebP, or JPEG where the browser can't), and you can zoom and save
  them.
- **Profile pictures** – picked with a round crop you can drag and zoom.

## Stack

- **Flutter** for Android and the web, from one codebase.
- **Firebase**:
  - Authentication (Google sign-in)
  - Cloud Firestore
  - Cloud Storage
  - Hosting

There is no server code. Access is enforced by
[`firestore.rules`](firestore.rules) and [`storage.rules`](storage.rules).
The Firebase config in this repo is public by design; it identifies the
project but grants nothing on its own.

```text
lib/
  auth/           Google sign-in and the members gate
  data/           models and JournalStore (all Firestore/Storage access)
  home/           the stem: timeline, layout, painters, replay
  add/            add-photos and add-moment sheets, photo pipeline
  moment/         a moment's page: photos, story, reflections
  viewer/         full-screen photo viewer
  anniversaries/  anniversary list and editor
  trash/          the 30-day trash
  theme/          colours, type, motion tokens
tool/             icon generator
```

## Run your own

You need Flutter (stable), the
[Firebase CLI](https://firebase.google.com/docs/cli) and
[FlutterFire CLI](https://firebase.google.com/docs/flutter/setup).

1. **Create a Firebase project.** It must be on the Blaze plan, which Cloud
   Storage needs; two people's use stays within the free quota. In the
   project, enable:
   - Authentication → Google sign-in
   - Firestore
   - Storage

2. **Point the app at your project.** This replaces
   `lib/firebase_options.dart` and `android/app/google-services.json`.

   ```sh
   flutterfire configure
   ```

   Then set your project id in `.firebaserc`.

3. **Deploy the security rules.** When the CLI asks to let Storage rules
   read Firestore, accept: the rules check membership there.

   ```sh
   firebase deploy --only firestore:rules,storage
   ```

4. **Allow the web app to download photo bytes.** Saving a photo needs this.

   ```sh
   gcloud storage buckets update gs://YOUR-BUCKET --cors-file=storage-cors.json
   ```

5. **Add the two of you by hand** in the Firestore console. Nothing in the
   app can write these:

   | Document | Fields |
   | --- | --- |
   | `people/{personId}` | `name` (string), `color` (`"sakura"` or `"sage"`) |
   | `members/{email}` | `person` (the personId) |

   One person can have several emails: add a `members` document for each.

6. **Run it.**

   ```sh
   flutter run -d chrome   # or an Android device
   ```

   Then set the day you got together from the link in the home screen's
   header.

### Android sign-in and release builds

- **SHA fingerprints.** Google sign-in on Android needs your signing key's
  SHA-1 and SHA-256 in the Firebase console, under Project settings → your
  Android app. `cd android && ./gradlew signingReport` prints them.
- **Signing releases.** Create an upload keystore, then add
  `android/key.properties`. git ignores this file.

  ```properties
  storePassword=…
  keyPassword=…
  keyAlias=upload
  storeFile=/path/to/upload.jks
  ```

  Without the file, release builds fall back to the debug key.

### Hosting

```sh
flutter build web --release
firebase deploy --only hosting
```

### Icons

All icons are rendered from the app's own flower widget. After changing
it, regenerate them:

```sh
flutter test tool/make_icons_test.dart
```
