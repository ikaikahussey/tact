# Tact

Tact is an iOS app for keeping notes about the people in your life. Add a person, link them to a Contacts card, jot down what you want to remember, and study them back with the grid, flashcard and puzzle views.

Data stays on the device, with a copy in the user's own iCloud account (when iCloud is on) so it survives deleting and reinstalling the app. There is no account, no server of ours and no analytics.

## Building

Open `Tact.xcodeproj` in Xcode 16 or later and run the `Tact` scheme. The project uses synchronized folders, so new files added under `App/` or `Tests/TactTests/` are picked up automatically.

From the command line:

```bash
xcodebuild -project Tact.xcodeproj -scheme Tact -destination 'platform=iOS Simulator,name=iPhone 17' build
```

```bash
xcodebuild -project Tact.xcodeproj -scheme Tact -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`Project.json` is an equivalent [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec for anyone who prefers to regenerate the project.

## Layout

| Folder | Contents |
| --- | --- |
| `App/Models` | `Person`, `Note`, `ContactSnapshot` and the settings types. Plain `Codable` values. |
| `App/Store` | `TactStore` (the single source of truth, all mutations) and `PersistenceController` (JSON files plus one JPEG per photo in Application Support, with migration from the 1.0 UserDefaults format). |
| `App/Games` | Flashcards and the colour derivation for Random Colors. |
| `App/Views` | SwiftUI screens, grouped by tab. |
| `App/Support` | Small helpers: outline export, Contacts conversion, colours. |
| `Tests/TactTests` | XCTest unit tests for the models, persistence, store rules and puzzle logic. |

## Before submitting to the App Store

Things that need a human with the developer account, in the order you will hit them:

1. **Bundle identifier.** `PRODUCT_BUNDLE_IDENTIFIER` is `app.bitrig.ikaikahussey.tact` in both targets. Change it if you want a different one, then register it in App Store Connect.
2. **Signing.** Both targets are set to team 3D52FT6PP7 with automatic signing; Xcode must be signed in to that account.
   The app uses the iCloud Documents capability with container `iCloud.app.bitrig.ikaikahussey.tact` (`App/Tact.entitlements`). Automatic signing registers it on the first device build or archive; if it does not, add the container under Certificates, Identifiers & Profiles > iCloud Containers and enable iCloud on the App ID.
3. **Privacy policy URL.** Required because the app requests Contacts access. The app sends nothing to the developer; data is backed up only to the user's own iCloud account. The policy can say so.
4. **App Privacy answers in App Store Connect.** Data is not collected. `App/PrivacyInfo.xcprivacy` already declares the UserDefaults use.
5. **Screenshots and description.** Take screenshots from the simulator for the 6.9" and 6.5" sizes.
6. **Version and build.** Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for each upload.

The List view has an outline mode (toggled by the small button on the People header line, remembered in `peopleListShowsNotes`) that shows each person with their notes beneath them, newest first (`PeopleOutlineRows`); each person can be collapsed with their chevron. The Tiles view is a free-play canvas: each person is a square showing one of eight geometric patterns in shades of their colour (`TileArt`, stored on `Person`; `TilePattern`, picked from the person's seed). Tapping a tile opens the person; touching and holding it offers colour and rotation, and tiles can be dragged to any cell (`TileLayout`). Shapes live only in the Tangram view. The Tangram view (`TangramGridContent`) is a second canvas where cells are split along their diagonals so pieces fit together like a tangram: two right triangles can share a cell, and squares turn 45° into diamonds spanning a two-by-two block with triangles in the corners (`TangramPiece`, `TangramLayout`; placement shared with Tiles in `GridPlacement`). A triangle dropped where it overlaps turns to fit if it can. Fit Together (`TangramLayout.packed`) repacks every piece as tightly as it can: it tries many random placement orders, and each press picks a different arrangement from the snuggest ones found. The Puzzle view (`ArtPuzzleView`) is a 4×4 sliding picture puzzle using a bundled default picture or a photo chosen in Settings (`ArtSettingsView`, `SlidingPuzzle`, `ArtImageCache`). The Random Colors and Flashcards layouts are implemented but hidden from Settings (`PeopleLayout.available`) until they are wanted.

Minimum iOS version is 17.0. The app is iPhone-only (it runs on iPad in compatibility mode).
