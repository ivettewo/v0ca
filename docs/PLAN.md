# v0ca. — Development Plan

A local macOS voice transcription app: global hotkey → HUD recording capsule → a local model transcribes → the text is inserted into the active app. Everything is offline, nothing leaves the computer.

**Stack:** Swift + SwiftUI, macOS 14+ (Apple Silicon prioritized).
**ASR engines:** WhisperKit (CoreML, the Whisper family) + FluidAudio (Parakeet and others) through a shared `TranscriptionEngine` protocol. A catalog of 30–40 models — see [MODELS.md](MODELS.md).
**Design:** mockups in `design/`, tokens and fonts — see [DESIGN.md](DESIGN.md).

---

## Stage 1 — Core (the recording work loop)

Goal: press ⌥ Space → record → the text is inserted. This is the minimally useful version.

1. **Project skeleton**: Xcode project, menu-bar-only app (`LSUIElement`), menu-bar icon, SPM dependencies (WhisperKit, FluidAudio, KeyboardShortcuts).
2. **Global hotkey** ⌥ Space (the KeyboardShortcuts library by sindresorhus), toggle and push-to-talk modes.
3. **Audio capture**: AVAudioEngine, 16 kHz mono, levels for the waveform, microphone permission request.
4. **HUD window**: a borderless floating NSPanel above all windows, bottom-center of the screen, does not steal focus. States: hidden → recording (red dot + waveform) → "Transcribing…" (spinner) → done (green checkmark) → hidden. Animations per the mockup.
5. **Transcription**: WhisperKit with a single default model (small); downloaded on first launch, after which the model is preloaded into memory at app startup and always stays warm (no warm-up delay when the hotkey is pressed).
6. **Text insertion**: copy to the clipboard + synthetic ⌘V via CGEvent (requires the Accessibility permission). Restoring the previous clipboard contents is optional.
7. **Permissions onboarding**: a screen requesting Microphone + Accessibility.

Stage outcome: the app can be used every day.

## Stage 2 — Settings and the model catalog

1. **Settings window** 920×640 with a sidebar (General / Models / Sound / History) — per the `Экран · Настройки.dc.html` mockup.
2. **General**: push-to-talk, recognition language (auto-detection), translation to English, VAD, appending a space, editable hotkeys (4 of them), insertion method, launch at login, window hiding, menu-bar icon, HUD position, model auto-unload timer, interface language.
3. **Models**: the full catalog (30–40 models, [MODELS.md](MODELS.md)): search, language filter, cards with description/size/accuracy/speed, download with progress, deletion, selecting the active one. The `TranscriptionEngine` abstraction for WhisperKit + FluidAudio.
4. **Sound**: microphone selection, a level indicator with a test, start/end sound cues, ducking system audio during recording, output device.
5. **Appearance**: light/dark/system theme, 5 accent colors.

## Stage 3 — History and dictionary

1. **History**: SQLite (GRDB) or SwiftData; cards with date, duration, text; copy / favorite / re-transcribe / delete; an audio player with progress; history size limit and auto-deletion; the recordings folder in Finder; ⌘F search.
2. **User dictionary**: hint terms for the model (prompt/initial tokens in Whisper), pills with add/remove.
3. **Post-processing**: clipboard handling, auto-send (Enter after insertion), a space after insertion.

## Stage 4 — Polish

- Finishing the HUD animations per the mockup, audio feedback.
- Interface localization (Russian/English) — done.
- Onboarding — done (full-window first-run wizard). Still ahead: About, auto-updates (Sparkle), notarization and DMG.

---

## Verification

- Manual end-to-end test: hotkey in any app → dictation → text inserted.
- Unit tests for the model catalog, the HUD state machine, and text post-processing.
- Build and run through XcodeBuildMCP (build_run_sim doesn't fit — this is a macOS app; use build macOS + launch).
