# Tact

Tact is an iOS app for keeping notes about the people in your life. Add a person, link them to a Contacts card, jot down what you want to remember, and study them back with the grid, flashcard and puzzle views.

Everything stays on the device. There is no account, no server and no analytics.

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
3. **Privacy policy URL.** Required because the app requests Contacts access. The app never uploads anything; the policy can say so.
4. **App Privacy answers in App Store Connect.** Data is not collected. `App/PrivacyInfo.xcprivacy` already declares the UserDefaults use.
5. **Screenshots and description.** Take screenshots from the simulator for the 6.9" and 6.5" sizes.
6. **Version and build.** Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for each upload.

The Tiles view is a free-play canvas: each person is a filled square, right-angle triangle or circle (`TileArt`, stored on `Person`), one cell or two-by-two. Tapping a tile opens the person; touching and holding it offers shape, colour and rotation, and tiles can be dragged to any cell (`TileLayout`, which pushes aside tiles a large tile lands on). The Tangram view (`TangramGridContent`) is a second canvas where cells are split along their diagonals so pieces fit together like a tangram: two right triangles can share a cell, and squares turn 45° into diamonds spanning a two-by-two block with triangles in the corners (`TangramPiece`, `TangramLayout`; placement shared with Tiles in `GridPlacement`). A triangle dropped where it overlaps turns to fit if it can. Fit Together (`TangramLayout.packed`) repacks every piece as tightly as it can, trying several placement orders and and each press picks a different arrangement at random from the snuggest ones found. The Random Colors and Flashcards layouts are implemented but hidden from Settings (`PeopleLayout.available`) until they are wanted.

Minimum iOS version is 17.0. The app is iPhone-only (it runs on iPad in compatibility mode).
