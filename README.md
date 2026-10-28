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
| `App/Games` | The game registry (`TileGame`), the Sliding Puzzle, Lights Out, Mosaic, Flashcards and the colour derivation for Random Colors. |
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

There is one root screen and no tab bar. A floating switch at the bottom (`ViewSwitch`) picks the grid of tiles, **People** (`PeopleLayout.standard`), the list, **Notes**, or a game on the back of the tiles, **Games** (`PeopleLayout.available`, `viewTitle`); the choice is remembered in `peopleLayout`, and there is no separate notes screen or query. The list (`PeopleListContent`) is one section per person headed by their name and note count, with their notes beneath, newest first (`PeopleSearch.sections`); Edit shows one row per person for reordering and deleting, and notes can be swiped away. Every screen sits under the same one-row header (`TactHeader`): the Tact wordmark (tap to pop back to the root grid), the view name on pushed screens, then search, add and a More menu holding Edit and Settings (`HeaderAction.actions`, `moreItems`). Search expands into the header and filters whichever mode is showing by person name and note text (`PeopleSearch`); a query starting with `#` matches notes carrying exactly that tag. Tags are hashtags typed in a note's text (`NoteTags`, never stored on their own), shown as tappable chips under the note in Notes, on the person's screen and in the editor (`TagChips`); typing `#` in an editor offers the existing tags above the keyboard (`TagSuggestionStrip`), and the open search field shows the tags in use, most used first (`TagRow`). the add button adds a person in the grid and a note in the list; Settings opens as a sheet.

The grid is a free-play canvas: each person is a square showing their photo or one of eight geometric patterns in shades of their colour (`TileArt`, stored on `Person`; `TilePattern`, picked from the person's seed unless they choose one under Tile on their screen). Settings offers five colour palettes, Classic, Pastel, Earthy, Jewel and Grayscale, shown as gradient discs, that recolour tiles, Tangram pieces and the app's accent (`AppPalette`). Tapping a tile opens the person; touching and holding it offers colour and rotation, and tiles can be dragged to any cell (`TileLayout`); the round Bring Together button closes the gaps, keeping their order. A search hides the tiles that do not match, leaving the rest in place (`PeopleGridItems`).

Games are the back of the tiles. The Games segment of the switch is a menu of every `TileGame` in `TileGame.all`; choosing one turns each tile over in a diagonal wave (`TileFlipFace`) and the game's pieces turn into view in their place (`GamesSurface`), on the same four-column grid, given a `TileGameContext` with the canvas size, whether it is face up, and the flip stagger. Every game stays loaded while the tiles are open, so each keeps its progress; the chosen game is remembered in `tilesGame`. The games offered are the Sliding Puzzle (`SlidingPuzzleGame`, `PuzzleBoard`, `PuzzleGame`: a 4×4 sliding picture puzzle using the Tact tiles, `TactTilesImage`, or a photo chosen in Settings), Simon (`SimonGame`, `Simon`, `SimonSynth`: sixteen pads on a pentatonic scale that are a keyboard between rounds, following the Sound settings), and Mosaic (`MosaicGame`, `Mosaic`: a quilt stamped from everyone's motifs, with an 8×8 FatBits editor, `FatBitsEditor`, for stamps of your own). Tangram (`TangramGridContent`, `TangramPiece`) and Lights Out (`LightsOutGame`, `LightsOut`) are kept in the code but not offered. The Random Colors and Flashcards layouts are implemented but hidden (`PeopleLayout.available`) until they are wanted.

Minimum iOS version is 17.0. The app is iPhone-only (it runs on iPad in compatibility mode).
