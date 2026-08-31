# v0ca. — Modules: implementation plan

Concept and rules: `OVERVIEW.md`. This is the order of work, the concrete
couplings that have to be cut, and what "done" looks like for each step.

Every step ends with the app building and running exactly as before. Nothing here
changes behaviour — if a step changes what the user sees, it went wrong.

## Layout

```
v0ca/
├── modules/
│   ├── V0caCore/          # paths, Prefs, Localization, Log
│   ├── DesignSystem/      # tokens and controls
│   ├── Providers/         # catalog, client, Keychain
│   ├── ScreenCapture/
│   ├── Stats/             # StatsStore + Stats tab
│   ├── Achievements/      # catalog, flags, shelf
│   └── AskFlow/           # AskSession, bubble, Markdown
├── v0ca/                  # the app target: core loop + composition
└── project.yml
```

Each module is a Swift package with its own `Package.swift`. XcodeGen wires them
in as local packages:

```yaml
packages:
  Achievements:
    path: modules/Achievements
targets:
  v0ca:
    dependencies:
      - package: Achievements
```

Releases include every package. Dropping one from `dependencies` is the escape
hatch described in `OVERVIEW.md`, not the normal path.

## Step 0 — Preparation (no packages yet)

Cut the couplings that would otherwise force circular dependencies. All of this
happens inside the current single target and is worth doing regardless.

1. **`AppPaths`.** `StatsStore` and `AchievementsStore` currently reach for
   `HistoryStore.baseFolder`. Move the folder to a standalone `AppPaths.base` /
   `AppPaths.recordings`; history stops being the owner of the app's directory.
2. **Theme and Prefs.** `Theme.apply()` reads `Prefs.Key.appTheme` and
   `AccentStore` reads `Prefs.Key.accentColor`, so the design system depends on
   app preferences. Either both keys move into `V0caCore` (simpler), or the design
   system takes them through an injected protocol (purer). Pick the first.
3. **`AskSession`'s four stores.** It holds keys, history, stats and achievements.
   Replace the last two with narrow protocols — `QuestionCounting`,
   `AchievementMarking` — declared in `AskFlow` and satisfied by the app.
4. **Achievements' reach.** The catalog reads `ModelManager.itemStates`,
   `HistoryStore.records`, `KeyboardShortcuts`, `AccentStore` and `Prefs`.
   Introduce one `AchievementContext` protocol with the handful of facts it
   actually needs (`downloadedModelCount`, `hotkeyChanged`, `hasFavorite`, …) and
   let the app assemble it. This is the largest single piece of step 0.

**Done when:** the app builds, the graph has no cycles, and nothing outside
`Core` reads `HistoryStore.baseFolder`.

## Step 1 — `V0caCore`

Move `Prefs`, `Localization`, `Log`, `AppPaths`. Everything that leaves the module
becomes `public`; `Prefs.Key` in particular is referenced everywhere.

Watch out: `L()` is `@MainActor` and used from views constantly — keep it that
way, and export `L10n` so modules can contribute their own strings (see step 5).

**Done when:** the app target depends on `V0caCore` and compiles.

## Step 2 — `DesignSystem`

Move `Tokens`, `Accent`, `Theme`, `Buttons`, `Controls`, `Dropdown`, `Indicators`,
`Layout`, `Modifiers`, `HeaderGradients`, `WindowChrome`.

The mechanical part is access levels: `Tokens` alone has ~40 members, and every
`SectionLabel`, `RowDivider`, `DSButton` used by a feature needs `public` plus a
`public init` — SwiftUI structs get an internal memberwise initialiser by default,
which is the single most common error in this step.

**Done when:** modules can draw without importing the app target.

## Step 3 — Leaf modules

In this order, because each one is smaller than the last coupling it removes:

1. **`ScreenCapture`** — one file, one dependency on `Log`. The rehearsal.
2. **`Providers`** — catalog, `ProviderClient`, `ProviderKeyStore`, providers tab.
3. **`Stats`** — `StatsStore`, stats tab, charts, `StatsMetricsCard`.
   `DictationTab` also uses the metrics card: it stays in the app and imports
   `Stats`, or the card moves to `DesignSystem`. Prefer the latter.
4. **`Achievements`** — store, catalog, shelf. Depends on the context protocol
   from step 0, not on stats directly.
5. **`AskFlow`** — session, bubble, `AnswerText`. Depends on `Providers` and
   `ScreenCapture`.

**Done when:** every module builds on its own, and the app is what glues them.

## Step 4 — The registry

The app needs to compose modules without naming them in twenty places. Two seams
are hardcoded today and must become lists:

- **Settings tabs.** `SettingsRootView.Tab` is a fixed enum with a `switch` for
  the icon, the gradient and the view. It becomes a `SettingsTab` value:
  `id`, `title`, `icon`, `gradient`, `placement` (main list or pinned to the
  bottom, where Stats lives), and a view builder.
- **HUD modes.** `Prefs.HUDMode` is a fixed enum used for the bar menu, the
  tints, the shortcuts and the routing in `RecordingCoordinator.finish()`.
  It becomes a registered list; `AskFlow` contributes "Ask" and "Screen".

```swift
protocol AppModule {
    static var id: String { get }             // "module.<id>.enabled"
    static var title: String { get }          // shown in the Modules screen
    static var summary: String { get }        // one line under the title
    static var requires: [String] { get }     // ids this module needs
    static func install(into registry: ModuleRegistry)
}
```

`install` is where a module adds its settings tab, its HUD modes, its achievement
groups and its localization table.

Registration stays explicit in the app target:

```swift
#if canImport(Achievements)
AchievementsModule.install(into: registry)
#endif
```

Explicit beats clever here: the list of modules in a build is one readable file,
not a runtime scan.

**Done when:** removing a package from `project.yml` removes its tab and its
modes and the app still builds — and, more to the point, the registry can be
asked what is installed so step 6 has something to list.

## Step 5 — Localization from modules

`L10n.en` is a single dictionary in the app. Each module needs to bring its own
strings, so `L()` looks through a list of tables that modules append to during
`install`. Keys stay Russian, the fallback stays "return the key".

The audit script from step 8 has to walk modules too.

## Step 6 — The Modules screen

This is the user-facing half of the whole exercise, and the only part of this
plan that ships a visible feature.

**Where.** Its own sidebar item, Modules, below Permissions. Not a section
inside General: that tab is already long, and a list that changes what the app
consists of deserves its own place.

**A row per module.** Title and one line of description from `AppModule`, an
`AccentToggle` on the right — the same `SettingRow` every other setting uses.
Only optional modules appear; recording, transcription and insertion are the app
and have no switch.

**State** lives in `UserDefaults` under `module.<id>.enabled`, defaulting to
**off** — see the rule in `OVERVIEW.md`. A fresh install therefore behaves
exactly as a build with no module system at all, and every module in it is
something the user asked for.

**Turning one off** must take effect without a restart: the tab disappears from
the sidebar, contributed HUD modes drop out of the bar menu, the module's hotkeys
are unregistered, and its observers stop. Everything involved is already
`@Observable`, so this is wiring rather than new machinery. Two places need care:
`KeyboardShortcuts` registrations have to be removed, not merely ignored, and if
the currently selected HUD mode belonged to the module, the bar falls back to
dictation.

**Dependencies between modules.** `AskFlow` cannot work without `Providers`.
Rather than letting the user create a broken combination, a row whose requirement
is off is shown disabled with the reason spelled out ("Requires Providers"), and
switching off a module that others depend on asks for confirmation and takes them
with it. `AppModule` gains `requires: [String]` for this.

**Data is kept.** `stats.json`, `achievements.json` and provider keys stay on
disk when a module is switched off — off means invisible, not erased. Deleting
data stays a separate, explicit action.

**Done when:** a full build can be reduced to a plain dictation app from the UI,
and switched back, without a restart and without losing anything.

## Step 7 — Data packs (optional, later)

Only after the above. A pack is a JSON file in Application Support, no code:

```json
{ "id": "pack.marathon", "group": "volume", "metric": "totalWords",
  "goal": 1000000, "title": "A million words", "icon": "book" }
```

`metric` names something the app already counts. Unknown metrics are skipped, not
an error — the same rule that already protects `achievements.json` from unknown
flags. Nothing here executes.

## Step 8 — Housekeeping

- Update `docs/ARCHITECTURE.md`: the module map replaces the flat tree.
- Keep the localization audit as `scripts/check_localization.py` and run it before
  a release.
- One commit per step, each one green.

## Risks

**Access-level churn.** The bulk of the diff will be `public` keywords. It reads
like noise in review and hides real changes. Mitigate by doing steps 1–3 as
separate commits, one module each.

**Sideways dependencies.** The moment two modules need each other, the design is
wrong. Push the shared piece down into `V0caCore` or express it as a protocol; do
not add a dependency between siblings.

**The registry becoming a framework.** It is a list of tabs and modes, not a
plugin engine. If `ModuleRegistry` grows past a couple of hundred lines,
something has gone wrong.

**Scope.** This is refactoring: no new behaviour, no new screens. If a step starts
producing user-visible change, it has drifted.

## Not in scope

Downloadable native modules. The reasoning is in `OVERVIEW.md`; the short version
is that this app holds Accessibility, Screen Recording and API keys, and loading
third-party code into that process is not a step to take for convenience.
