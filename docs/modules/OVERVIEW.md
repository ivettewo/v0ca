# v0ca. — Modules

How the app is meant to come apart, and what a "module" is allowed to be.

## The idea in one paragraph

Everything that is not the core loop — hotkey, recording, local transcription,
insertion — lives in its own Swift package under `modules/`. All of them ship in
this repository, are cloned with it, and are compiled into every build. Which of
them are *active* is decided by the person using the app, in a Modules screen in
Settings.

## Two layers, and why both are needed

The word "module" gets used for two different things, and conflating them is how
plugin systems turn into a mess.

**Run-time activation — the one users see, and the default mechanism.** Every
module is compiled in. The Modules screen in Settings lists them, and switching
one off hides its tab, stops its counters and unregisters its hotkeys. One build
is produced, tested, signed and notarised; the person decides what they want
running. Data a switched-off module owns is kept, not erased — off means
invisible, not wiped.

**Build-time inclusion — available, not used by default.** A module is a Swift
package, so dropping it from the target's dependencies leaves its code out of the
binary entirely. Normal releases include everything and this stays unused, but
the capability is worth keeping for one reason: a toggle and an absent binary are
different promises.

The distinction matters for exactly one claim. "This build cannot reach the
network" is provable only by building without `Providers` and `AskFlow`; with
them compiled in and merely switched off, the networking code is still there and
the guarantee is a matter of trust in our own flag. For an app that sells itself
on being offline, keeping that build possible costs nothing once the split is
done.

## What we are deliberately not doing

**No downloadable native code.** Not now, and the bar for changing that is high.
The app holds Accessibility (it can type into any application), Microphone,
Screen Recording, and provider API keys in the Keychain. A `.dylib` loaded into
this process inherits all of it. Shipping that channel would mean:

- turning off library validation (`com.apple.security.cs.disable-library-validation`),
  which the hardened runtime enables for a reason;
- stripping the quarantine attribute from a downloaded file, i.e. stepping around
  Gatekeeper on the user's behalf;
- accepting that one compromised repository equals a keylogger with screen capture
  and someone else's paid API key.

For an app whose whole promise is "nothing leaves your Mac", that trade is not
worth making for the sake of a pack of achievements.

**Extensibility without executable code is a different question.** A pack of
achievements is a list of `{id, title, metric, threshold}` — data, not logic.
Dictionaries, prompt sets, provider catalogs are the same shape. Those can be
downloaded, checksummed and parsed with no code execution at all; the app already
does exactly this with `ModelCatalog.json`. That road stays open and is described
in `PLAN.md`, step 6.

If a pack ever needs real logic rather than thresholds, the next step is a
scripting layer (`JavaScriptCore`), where the module sees only the API we hand
it — a different class of risk from a Mach-O in our address space.

## The dependency rule

Modules form a layered graph and never call sideways:

```
                 App (v0ca target)
                   │ composes, owns the registry
   ┌───────────────┼────────────────┬──────────────┐
Stats        Achievements       AskFlow        Providers
   └───────────────┴────────────────┴──────────────┘
                   │
              DesignSystem
                   │
                V0caCore
        (paths, prefs, localization, logging)
```

A module may depend on the layers below it and on nothing at its own level. When
two modules need each other — as achievements and stats do today — the shared
part moves down, or the coupling is expressed as a protocol the app satisfies.

## What is a module, and what is not

| Candidate | Verdict |
|---|---|
| Achievements | Module. Reads metrics, owns its own shelf UI. |
| Stats tab | Module. Owns `stats.json` and the charts. |
| Providers + Ask/Screen flow | Module. The only part that touches the network. |
| Screen capture | Module. Self-contained, one permission. |
| Design system | Module, but a foundation one — everything draws with it. |
| Recording, transcription, insertion | **Not** a module. This is the app, and it has no switch. |
| Notes index / RAG | Not a module. It needs storage, indexing, its own UI and a hook inside the question flow. Modularity helps only as a build edition. |

## Cost, honestly

The code is currently one target where everything is `internal` and therefore
visible to everything else. Splitting it means marking every cross-boundary type
`public`, and untangling the couplings that only work today because there are no
boundaries — `StatsStore` reaching for `HistoryStore.baseFolder`, `Theme` reading
`Prefs`, `AskSession` holding four stores at once.

That is a day of mostly mechanical work with no visible result. It buys clearer
seams, a Modules screen that means something, and the ability to hand someone a
module folder without handing them the whole app. It does not make the app faster
or add a single feature.
