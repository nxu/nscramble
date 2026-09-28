# NScramble

A minimal speedcubing timer for macOS, iPadOS and iOS: WCA-style 3×3 scrambles, a stackmat-style timer,
statistics, and optional sync between devices through a self-hosted server
([nscramble-server](../nscramble-server)).

## Features

- **Scrambles** — random-state 3×3 scrambles, generated the same way as cubing.js / TNoodle: a uniformly
  random cube state (rejecting states that are solved or one move away), solved with a Swift port of
  [min2phase](https://github.com/cs0x7f/min2phase), at most 21 moves. Verified against cubing.js.
  Skip to a new scramble without timing: ⌘→ or click the scramble (Mac), or swipe it to the right
  (iPhone/iPad).
- **Timer** — hold space (or touch) until the time turns green, release to start, any key or touch to stop.
  Esc stops the timer and records a DNF.
- **Penalties** — mark the last solve OK, +2, DNF, or delete it (soft delete, restorable with OK).
- **Statistics** — averages for today, the last 7 and 30 days, ao5 / ao12 / ao100, and today's solves.
- **Layouts** — a stats sidebar when there's room; a bottom tab bar (Timer / Stats / Sync) when there
  isn't (iPhone, narrow windows); a 400 × 200 mini view on the Mac.
- **Appearance** — follows the system light/dark setting, or can be forced to either.
- **Sync** — manual or automatic (on launch, every hour, after every 10 solves), offline first.

## Keyboard shortcuts

| Keys | Action |
|---|---|
| Space (hold, release) | Arm and start the timer |
| Any key | Stop the timer |
| Esc | Stop the timer as a DNF (or cancel a hold) |
| ⌘→ | New scramble |
| ⌘1 / ⌘2 / ⌘3 | Mark the last solve OK / +2 / DNF |
| ⌘⌫ | Delete the last solve |
| ⌘O / ⌘I | Normal view / mini view (Mac) |

A hardware keyboard works on iPad too; the ⌘ shortcuts are in the **Solve** menu.

## Statistics

Times are shown the WCA way: truncated to hundredths (`9.87`, `1:02.34`, `14.34+` for a +2, `DNF`).

- **Averages** drop the fastest and slowest 5% of the solves (rounded up, at least one from each end) and
  take the mean of the rest; ao5 and ao12 drop one each, ao100 drops five. A DNF counts as the slowest
  result; if more DNFs remain than are dropped, the average is DNF. At least 3 solves are needed.
  Averages are rounded to hundredths.
- **Periods** (today, 7 days, 30 days) use each solve's local calendar day and include today.
- Deleted solves are ignored; +2 is included in the time.

## Building

Requirements: macOS with Xcode 27 (Swift 6.4), and [Nix](https://nixos.org) with direnv for the dev shell
(`just`, `xcodegen`, `bun`). The Xcode project is generated from `project.yml` and not checked in.

```sh
direnv allow          # or: nix develop -c fish
just run-mac          # build and run the Mac app
just run-iphone       # … on the iPhone simulator (iPhone 17)
just run-ipad         # … on the iPad simulator (iPad (A16))
just run-sim device="iPhone Air"
just test             # all Swift package tests
just open             # generate the project and open it in Xcode
```

Other recipes: `build-mac`, `build-ipad`, `project` (regenerate `NScramble.xcodeproj`), `app-icon`
(redraw the icon from `scripts/app-icon.swift`), and `cubingjs-fixture` (regenerate the cubing.js
reference data used by the scrambler tests).

Local builds are ad-hoc signed ("Sign to Run Locally"). To run on a physical iPhone or iPad, set
`DEVELOPMENT_TEAM` in `project.yml`.

## CI and releases

GitHub Actions (`.github/workflows/`): every push and pull request runs the package tests and builds the
Mac and iOS apps. Pushing a version tag (`1.2.3` or `v1.2.3`) runs the tests and creates a GitHub release
with `NScramble-<version>-macos.zip` and `NScramble-<version>-ios-unsigned.ipa` (one IPA for iPhone and
iPad). The tag becomes the app version (a pre-release suffix like `-beta.1` is dropped from the app's version
number but kept in the file names, and the release is marked as a pre-release); the build number is the CI run
number. The same packages can be built locally with `just package-mac <version>` and `just package-ios <version>`.

The builds are not signed with a developer certificate: the Mac app is ad-hoc signed (macOS will ask to
confirm opening it the first time), and the IPA must be signed before it can be installed (e.g. with
Sideloadly or AltStore, or by setting `DEVELOPMENT_TEAM` and building from Xcode).

## Project layout

```
App/                      SwiftUI app (macOS, iPadOS, iOS)
  Sources/                screens, app model, sync UI, Keychain, mini window
  Resources/Assets.xcassets  app icon, tab and settings icons
Packages/
  ScrambleKit/            min2phase port, random-state scrambles, WCA filter
  StatsKit/               averages, time formatting, penalties
  TimerKit/               the timer state machine (hold / run / stop)
  Storage/                SQLite (GRDB): schema, migrations, queries, sync client
scripts/
  app-icon.swift          draws the app icon
  cubingjs-fixture/       generates scrambler test data with cubing.js (bun)
project.yml               XcodeGen spec
justfile, flake.nix       tasks and dev shell
```

The packages have no UI and are tested with `swift test`; everything Apple-specific (SwiftUI, AppKit,
Keychain) lives in `App/`.

## Data

Solves are stored locally in SQLite: on the Mac in
`~/Library/Application Support/NScramble/nscramble.sqlite`, on iOS in the app's container. Each solve has
a UUIDv7 id, its local date (`YYYY-MM-DD`), time in milliseconds, scramble, penalty (0 none, 1 +2, 2 DNF)
and `created_at` / `updated_at` / `deleted_at` timestamps (epoch milliseconds). Deletes are soft.

## Sync

Sync is optional. Run [nscramble-server](../nscramble-server), then in the app open the sync settings
(the cog next to **Sync now**), enter the server URL and API key, and save. The key is stored in the
Keychain; the URL must be `https://` (plain `http://` is allowed for `localhost` / `127.0.0.1`).

Each device keeps its full history locally and exchanges changes with the server: it pushes solves that
changed locally and pulls everything changed since its last sync. When two devices edit the same solve,
the later edit wins. Switching to a different server starts over (every solve is pushed again). The
protocol is documented in `Packages/Storage/Sources/Storage/Sync.swift`.

## License and credits

GPL-3.0 (see [LICENSE](LICENSE)).

- The scrambler is a port of [min2phase](https://github.com/cs0x7f/min2phase) by Chen Shuang (GPL-3.0),
  checked against [cubing.js](https://github.com/cubing/cubing.js).
- Storage uses [GRDB.swift](https://github.com/groue/GRDB.swift).
- The tab and settings icons are free icons from Font Awesome Pro 5
