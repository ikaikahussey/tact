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
| `App/Games` | The Sliding Puzzle, the game registry, Flashcards and the colour derivation for Random Colors. |
| `App/Views` | SwiftUI screens: the shared header, the People root (grid and list), person and note details, games and settings. |
| `App/Support` | Small helpers: outline export, Contacts conversion, colours. |
| `Tests/TactTests` | XCTest unit tests for the models, persistence, store rules and puzzle logic. |

## Before submitting to the App Store

Things that need a human with the developer account, in the order you will hit them:

1. **Bundle identifier.** `PRODUCT_BUNDLE_IDENTIFIER` is `app.bitrig.ikaikahussey.tact` in both targets. Change it if you want a different one, then register it in App Store Connect.
2. **Signing.** Both targets are set to team 3D52FT6PP7 with automatic signing; Xcode must be signed in to that account.
   The app uses the iCloud Documents capability with container `iCloud.app.bitrig.ikaikahussey.tact` (`App/Tact.entitlements`). Automatic signing registers it on the first device build or archive; if it does not, add the container under Certificates, Identifiers & Profiles > iCloud Containers and enable iCloud on the App ID.
3. **Privacy policy and support URLs.** App Store Connect requires both; the privacy policy is also required by App Review inside the app. Publish the page, enter it in App Store Connect, and set `TactLinks.privacyPolicy` (`App/Support/TactLinks.swift`), which the Privacy Policy row in Settings opens. The app sends nothing to the developer; data is backed up only to the user's own iCloud account. The policy can say so.
4. **App Privacy answers in App Store Connect.** Data is not collected. `App/PrivacyInfo.xcprivacy` already declares the UserDefaults use.
5. **Screenshots and description.** Take screenshots from the simulator for the 6.9" and 6.5" sizes.
6. **Version and build.** Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for each upload.

There is one root screen and no tab bar. It opens on the grid of tiles, **People** (`PeopleLayout.standard`), and the header toggles to the list, **Notes** (`PeopleLayout.viewTitle`); the choice is remembered in `peopleLayout`, and there is no separate notes screen or query. The list (`PeopleListContent`) is one section per person headed by their name and note count, with their notes beneath, newest first (`PeopleSearch.sections`); Edit shows one row per person for reordering and deleting, and notes can be swiped away. Every screen sits under the same one-row header (`TactHeader`): the Tact wordmark (tap to pop back to the root grid), then a people/notes switch on the root or the view name elsewhere, then search, games, add, edit and settings (`HeaderAction.actions`). Search expands into the header and filters whichever mode is showing by person name and note text (`PeopleSearch`); the add button adds a person in the grid and a note in the list; Settings opens as a sheet.

The grid is a free-play canvas: each person is a square showing their photo or one of eight geometric patterns in shades of their colour (`TileArt`, stored on `Person`; `TilePattern`, picked from the person's seed unless they choose one under Tile on their screen). Settings offers five colour palettes, Classic, Pastel, Earthy, Jewel and Grayscale, shown as gradient discs, that recolour tiles, Tangram pieces and the app's accent (`AppPalette`). Tapping a tile opens the person; touching and holding it offers colour and rotation, and tiles can be dragged to any cell (`TileLayout`); the round Bring Together button closes the gaps, keeping their order. A search hides the tiles that do not match, leaving the rest in place (`PeopleGridItems`).

The Games screen (`GamesView`, the puzzle-piece icon in the header) lists each `TileGame` in `TileGame.all` as a card; tapping one pushes it (`Route`). Each game draws on the same four-column grid as the tiles, given a `TileGameContext` with the canvas size. Tangram (`TangramGridContent`) is a table of pattern blocks: equilateral triangles, diamonds (two triangles), half hexagons (three) and hexagons (six), each shape in its own colour unless the person picks another (`TangramPiece`). Tap a piece to open the person, touch and hold for its menu, or turn it with two fingers (a sixth of a turn at a time). Pieces are not snapped to a grid; each has a free position, and dragging one pushes the pieces in its way aside like wooden blocks (`TangramLayout.settle`, a separating-axis test between the convex outlines, run on every drag update with the dragged piece held still). Fit Together (a small round shuffle button, `TangramLayout.packed`) repacks every piece snugly on the triangular lattice: it tries several placement orders, and each press picks a different arrangement from the tightest found. The Sliding Puzzle (`SlidingPuzzleGame`, `PuzzleBoard`, `PuzzleGame`) is a 4×4 sliding picture puzzle over the top four rows. From Games it uses the Tact tiles, the four logo letters drawn in a square (`TactTilesImage`), or a photo chosen in Settings (`ArtSettingsView`, `SlidingPuzzle`, `ArtImageCache`); opened from a person's screen (the Puzzle link by their tile) it uses their photo (`PuzzleImageSource`). The Random Colors and Flashcards layouts are implemented but hidden (`PeopleLayout.available`) until they are wanted.

Minimum iOS version is 17.0. The app is iPhone-only (it runs on iPad in compatibility mode).
