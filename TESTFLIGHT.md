# Shipping Tact to TestFlight

## One-time setup (needs your Apple Developer account)

1. **Sign in to Xcode.** Xcode > Settings > Accounts > add your Apple ID. Note the 10-character Team ID shown next to the team.
2. **Register the app.** In [App Store Connect](https://appstoreconnect.apple.com) > Apps > "+" > New App:
   iOS, name "Tact", bundle ID `app.bitrig.ikaikahussey.tact` (register it under Certificates, Identifiers & Profiles if it is not offered), SKU `app.bitrig.ikaikahussey.tact` (already created, Apple ID 6759739594).
   If you want a different bundle ID, change `PRODUCT_BUNDLE_IDENTIFIER` in both targets of `Tact.xcodeproj` first.
3. **Privacy policy URL** (and, for the App Store, a support URL). Required before external testers can be added. Set `TactLinks.privacyPolicy` in `App/Support/TactLinks.swift` to the same address. A short page saying the app stores data on the device and in the user's own iCloud account, and sends nothing to the developer, is enough.

## Each upload

From the repository root:

```bash
Scripts/testflight.sh
```

The team (3D52FT6PP7) is set in the project. The script archives a Release build with a timestamp build number, signs it with the Apple Distribution certificate in the login keychain and the "Tact App Store" profile, and uploads it with the team's App Store Connect API key. The key ID and issuer ID live in `~/.appstoreconnect/tact.env` (or `ASC_KEY_ID` / `ASC_ISSUER_ID` in the environment) and the `.p8` in `~/.appstoreconnect/private_keys/`; neither is in the repository. Processing takes a few minutes; then the build appears under TestFlight in App Store Connect.

The script does not use the Xcode login: `xcodebuild` run from a terminal cannot read the accounts Xcode keeps, so it fails with "Failed to Use Accounts" however often you sign in. The API key avoids that. API keys cannot use the team's cloud-managed distribution certificate either, which is why signing is manual. On a new Mac: Xcode > Settings > Accounts > Manage Certificates > + > Apple Distribution, then in the developer portal regenerate the "Tact App Store" profile (Profiles > App Store Connect > Tact > that certificate) and download it.

Or in Xcode: select "Any iOS Device (arm64)", Product > Archive, then Distribute App > TestFlight & App Store. That path uses the Xcode login and cloud signing and works independently of the above.

## Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in `App/Info.plist`, so TestFlight will not stop to ask about encryption. The app uses no encryption beyond the system's.

## What to Test (paste into TestFlight)

```
Tact 1.0 – first beta

Tact keeps notes about the people in your life. Everything stays on your phone.

Please try:
• Add a few people, give some a photo, and link one to a contact card.
• The floating switch at the bottom picks People, Notes or Games. The header has one row: tap TACT to come back to the grid, and use the icons for search, add (new person or note) and More (Edit, Settings).
• Notes is everyone with their notes beneath them, newest first. Tap + on a person to add a note about them, or + in the header for a new note linked to anyone. More > Edit reorders and deletes people in Notes and deletes tiles in People.
• Tap the search icon and type: the grid and the list both narrow to matching people and notes.
• Tag a note by typing #words in it, like #birthday. The tags appear as chips under the note; tap one to search for it. With the search field open, the tags you use are listed to tap, and typing # in a note offers them above the keyboard.
• In the grid, each person is a tile showing their photo or a pattern; choose which under Tile on their screen. Tap a tile to open the person. Touch and hold a tile to pick its colour or turn it, or drag it anywhere. The round grid button brings the tiles together again.
• Tap Games on the switch and pick a game: every tile flips over to it, and People flips them back. Tangram: tap a piece to open the person, touch and hold for its menu, drag to push the others, turn it with two fingers, and tap the shuffle button to fit everything together. Sliding Puzzle: slide the pieces to rebuild the Tact tiles, or choose your own photo. Open Puzzle from a person's screen to play with their photo. Lights Out: tap a light to flip it and its neighbours; turn them all off. Mosaic: pick a stamp from the strip, tap or drag on the canvas, tap a cell again to turn it; Fill and Clear are the round buttons. Your mosaic should still be there after relaunching.
```

## Beta App Review notes

TestFlight external testing goes through a light review. Suggested notes for the reviewer:

```
Tact is a personal notes app. No account is needed. "Link Contact" on a person opens the
system contact picker, which needs no Contacts permission; the chosen card's name, phone,
email and address are copied into the app's local storage. The Contacts usage string covers
an optional refresh of those details, which only happens if access has been granted.
The privacy policy is linked from Settings > About.

To see the games: on the People tab (Tiles), add 16 people with the + button, then tap the
round puzzle-piece button at the bottom right; every tile turns over to the Woodblock Puzzle,
and the selector at the bottom left switches to Tangram. A first-launch card explains this, and
a "N more to unlock games" label counts down until then.

The default puzzle picture is a 1-bit rendering of a public-domain Japanese woodblock print
from Rawpixel's public-domain collection (CC0). Data is backed up to the user's own iCloud account (iCloud Drive app
container) so it survives reinstalling; nothing is sent to the developer.
```

## Before each build

- Bump `MARKETING_VERSION` when the user-facing version changes (the build number is automatic).
- Run the tests: `xcodebuild -project Tact.xcodeproj -scheme Tact -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Check the About row in Settings shows the version you expect.
