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

The team (3D52FT6PP7) is set in the project. The script archives a Release build with a timestamp build number, signs it automatically, and uploads it. Processing takes a few minutes; then the build appears under TestFlight in App Store Connect.

Or in Xcode: select "Any iOS Device (arm64)", Product > Archive, then Distribute App > TestFlight & App Store.

To upload without being interactively signed in (CI), create an App Store Connect API key with the App Manager role and pass `ASC_KEY_PATH`, `ASC_KEY_ID` and `ASC_ISSUER_ID` as well.

## Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in `App/Info.plist`, so TestFlight will not stop to ask about encryption. The app uses no encryption beyond the system's.

## What to Test (paste into TestFlight)

```
Tact 1.0 – first beta

Tact keeps notes about the people in your life. Everything stays on your phone.

Please try:
• Add a few people, give some a photo, and link one to a contact card.
• Write notes from the Notes tab and from a person's screen. Link a note to more than one person.
• Switch the People view (tap the arrow beside "People") between Tiles and List; Settings is the gear at the top left. In List, tap + on a person to add a note about them, and the small outline button beside the People header shows each person with their notes beneath them. Each person is a tile.
• In Tiles (the view People opens on), each person is a tile showing their photo or a pattern; choose which under Tile on their screen. Tap a tile to open the person. Touch and hold a tile to pick its colour or turn it, or drag it anywhere. Try making a picture. The round grid button brings the tiles together again.
• In Tiles, once you have 16 people, tap the round puzzle-piece button to flip every tile over to the games on the back. The selector at the bottom left switches between them; the grid button flips back.
• Woodblock Puzzle: slide the pieces to rebuild the picture, and tap the photo button to use your own.
• Tangram: each person is a pattern block (triangle, diamond, half hexagon or hexagon; touch and hold to change). Drag pieces anywhere; they push each other out of the way like wooden blocks. Tap the round shuffle button to fit everything together snugly; tap again for a different arrangement.
• In Settings, try the Classic, Pastel, Earthy and Jewel colours: they recolour the tiles, Tangram pieces and buttons.
• Group Notes by person (tap the "Notes" header).
• Edit a note: change its date, add or remove people, then delete it.
• Force-quit and reopen: everything should still be there.
• With iCloud on, delete Tact, reinstall it from TestFlight and open it: your people and notes should come back within a minute (Settings shows "iCloud Backup: On").

Tell us about anything confusing, slow, or that lost data. Use the TestFlight screenshot feedback if you can.
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
