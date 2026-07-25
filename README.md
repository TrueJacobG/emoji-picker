# Emoji Picker

A small macOS menu-bar app. Press `§` from any app, search for an emoji, and it's pasted straight into the field you were typing in. Supports custom Slack-style shortcuts (`:super_smile:`), usage statistics, and launch-at-login.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)

## Install

1. Download `emoji-picker.zip` from the [Releases](../../releases) page.
2. Unzip and drag `emoji-picker.app` into `/Applications`.
3. The first launch is blocked by Gatekeeper because the app isn't notarized (no paid Apple Developer account — see [Why the warning?](#why-the-warning)). Use **one** of:
   - **System Settings** — double-click the app, click **Done** on the warning, then go to **Privacy & Security → Open Anyway**.
   - **Terminal** — `xattr -dr com.apple.quarantine /Applications/emoji-picker.app`
4. Open the app and grant the two permissions it asks for (via the menu-bar icon):
   - **Input Monitoring** — to see the global `§` keypress.
   - **Accessibility** — to paste the emoji into the focused field.

## Usage

- Press `§` from anywhere to open the picker.
- Type to filter, `↑` / `↓` to move, `Enter` to insert, `Esc` to cancel.
- Click the menu-bar icon to manage custom emoji, view statistics, toggle launch-at-login, or quit.

## Why the warning?

The app is built without a paid Apple Developer Program membership, so it can't be notarized. It **is** ad-hoc signed (the minimum macOS requires to load the executable), just not signed by a developer Apple has verified. The bypass in step 3 only needs to be done once per machine.

If you ever enroll in the Apple Developer Program, the upgrade path is: sign with `Developer ID Application`, submit to `notarytool`, then `stapler staple`.

## Development

Requires Xcode 16+ targeting macOS 26.0.

```bash
git clone https://github.com/TrueJacobG/emoji-picker.git
cd emoji-picker
open emoji-picker.xcodeproj
```

Run with **Product → Run**, or from the terminal:

```bash
# Debug build (ad-hoc signed, no developer account needed)
xcodebuild -project emoji-picker.xcodeproj -scheme emoji-picker \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

# Run unit tests (no accessibility/Input Monitoring prompts)
xcodebuild -project emoji-picker.xcodeproj -scheme emoji-picker \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  test
```

> **Note:** The test scheme runs only unit tests (`emoji-pickerTests`). UI tests are excluded because they require a signed runner and trigger system permission prompts.

### Cutting a release

```bash
xcodebuild -project emoji-picker.xcodeproj -scheme emoji-picker \
  -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build

ditto -c -k --sequesterRsrc --keepParent \
  build/Build/Products/Release/emoji-picker.app \
  emoji-picker.zip
```

Upload `emoji-picker.zip` as an asset on a new [GitHub Release](../../releases/new).

## Contributing

Contributions are welcome! Please read the [Code of Conduct](CODE_OF_CONDUCT.md) first.

1. Fork the repo and create a feature branch.
2. Make your changes. Add or update tests where reasonable.
3. Ensure `xcodebuild ... test` passes (see above).
4. Open a pull request describing what and why.

## License

This project is open source. See the repository for details.
