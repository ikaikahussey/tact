# Shipping Tact to TestFlight

## One-time setup (needs your Apple Developer account)

1. **Sign in to Xcode.** Xcode > Settings > Accounts > add your Apple ID. Note the 10-character Team ID shown next to the team.
2. **Register the app.** In [App Store Connect](https://appstoreconnect.apple.com) > Apps > "+" > New App:
   iOS, name "Tact", bundle ID `app.bitrig.ikaikahussey.tact` (register it under Certificates, Identifiers & Profiles if it is not offered), SKU `app.bitrig.ikaikahussey.tact` (already created, Apple ID 6759739594).
   If you want a different bundle ID, change `PRODUCT_BUNDLE_IDENTIFIER` in both targets of `Tact.xcodeproj` first.
3. **Privacy policy URL.** Required before external testers can be added, because the app asks for Contacts access. A short page saying the app stores data on the device and in the user's own iCloud account, and sends nothing to the developer, is enough.

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
• Switch the People view (tap the "People" header) between List, Tiles and Tangram. In List, tap + on a person to add a note about them, and the small outline button beside the People header shows each person with their notes beneath them. Each person is a tile.
• In Tiles, tap a tile to open the person. Touch and hold a tile to pick its shape (triangle, square, large triangle, large square or circle), colour or turn, or drag it anywhere. Try making a picture.
• In Tangram, triangles fit together along cell diagonals and squares can turn 45° into diamonds. Drop a triangle next to another piece and it turns to fit. Tap Fit Together to pack everything in snugly; tap again for a different arrangement.
• Group Notes by person (tap the "Notes" header).
• Edit a note: change its date, add or remove people, then delete it.
• Force-quit and reopen: everything should still be there.
• With iCloud on, delete Tact, reinstall it from TestFlight and open it: your people and notes should come back within a minute (Settings shows "iCloud Backup: On").

Tell us about anything confusing, slow, or that lost data. Use the TestFlight screenshot feedback if you can.
```

## Beta App Review notes

TestFlight external testing goes through a light review. Suggested notes for the reviewer:

```
Tact is a personal notes app. No account is needed. Contacts access is optional and only used
when the user taps "Link Contact" on a person; it copies name, phone, email and address into
the app's local storage. Data is backed up to the user's own iCloud account (iCloud Drive app
container) so it survives reinstalling; nothing is sent to the developer.
```

## Before each build

- Bump `MARKETING_VERSION` when the user-facing version changes (the build number is automatic).
- Run the tests: `xcodebuild -project Tact.xcodeproj -scheme Tact -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Check the About row in Settings shows the version you expect.
