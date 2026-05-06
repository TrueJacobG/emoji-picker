# Emoji Picker

A small macOS menu-bar app that lets you press `§` from any app, search for an emoji, and have it pasted straight into the field you were typing in.

## Install

1. Download `emoji-picker.zip` from the [Releases](../../releases) page.
2. Unzip it and drag `emoji-picker.app` into `/Applications`.
3. The first launch is blocked by Gatekeeper because the app is not notarized (see [Why the warning?](#why-the-warning) below). Use **one** of these to allow it:

   **Option A - System Settings (recommended).**
   - Double-click the app. macOS shows "Apple cannot verify that this app is free of malware" - click **Done**.
   - Open **System Settings → Privacy & Security**, scroll down, find the *"emoji-picker was blocked..."* row, and click **Open Anyway**.
   - Authenticate, then double-click the app again and choose **Open** in the second prompt.

   **Option B - Terminal one-liner.** Removes the quarantine flag in one go:

   ```bash
   xattr -dr com.apple.quarantine /Applications/emoji-picker.app
   ```

4. Open the app from the menu-bar icon and grant the two permissions it asks for:
   - **Input Monitoring** - so the app can see the global `§` keypress.
   - **Accessibility** - so the app can paste the emoji into the focused field.

   Both are requested from the popover with a "Grant..." button.

## Usage

- Press `§` from anywhere. A floating picker appears, focused on the search field.
- Type to filter, use `↑` / `↓` to move the selection, `Enter` to insert, `Esc` to cancel.
- Click the menu-bar icon to see permission status, toggle launch-at-login, view usage statistics, or quit.

## Why the warning?

The app is built without a paid Apple Developer Program membership ($99 / yr), so it can't be signed with a `Developer ID Application` certificate or notarized. macOS therefore treats it as coming from an "unidentified developer" and blocks the first launch. The bypass above only needs to be done once per machine. The app is **ad-hoc signed** (the binary itself is signed with a placeholder identity, which is what Apple silicon requires), it just isn't signed by a developer Apple has verified.

## Building from source

Requires Xcode (the project targets macOS 26.0).

```bash
git clone https://github.com/<you>/emoji-picker.git
cd emoji-picker
open emoji-picker.xcodeproj
```

Then **Product → Run** in Xcode, or:

```bash
xcodebuild -project emoji-picker.xcodeproj -scheme emoji-picker test
```

## Cutting a release

This is what produces the `emoji-picker.zip` that goes on the Releases page.

```bash
xcodebuild \
  -project emoji-picker.xcodeproj \
  -scheme emoji-picker \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

ditto -c -k --sequesterRsrc --keepParent \
  build/Build/Products/Release/emoji-picker.app \
  emoji-picker.zip
```

Notes:

- `CODE_SIGN_IDENTITY="-"` ad-hoc signs the binary. This is the minimum macOS (especially Apple silicon) needs to load the executable; it does **not** make Gatekeeper trust the app.
- `ditto -c -k --sequesterRsrc --keepParent` is the right way to zip a `.app` bundle. Avoid Finder's "Compress" or `zip -r` - both have a history of breaking symlinks / metadata in app bundles.
- Upload `emoji-picker.zip` as an asset on a new [GitHub Release](../../releases/new). That's all the hosting you need.

If you ever do enroll in the Apple Developer Program, the upgrade path is:

1. Switch the build to use your `Developer ID Application` certificate.
2. Re-sign with `--options runtime` to keep the existing Hardened Runtime setting.
3. Submit the resulting zip to `notarytool` for notarization.
4. `xcrun stapler staple emoji-picker.app` and re-zip.

That removes the Gatekeeper warning entirely.
