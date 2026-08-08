# v0ca. — Architecture

## Overall scheme

A menu-bar-only app (`LSUIElement = true`), without a main window. Three UI surfaces:

- **HUD** — a floating `NSPanel` (borderless, `.nonactivatingPanel`, level `.statusBar`, `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`), with SwiftUI content. It does not take focus away from the active app — this is critical for text insertion.
- **Settings** — a regular SwiftUI window (`Window`), 920×640.
- **Menu bar** — `MenuBarExtra` with status and quick actions.

## Modules

```
v0ca/
├── App/                  # entry point, AppDelegate, windows
├── Core/
│   ├── Hotkeys/          # KeyboardShortcuts: toggle + push-to-talk
│   ├── Audio/            # AVAudioEngine: 16kHz mono capture, RMS levels for the waveform
│   ├── Transcription/    # engines and the model catalog
│   │   ├── TranscriptionEngine.swift    # protocol
│   │   ├── WhisperKitEngine.swift       # the Whisper family (CoreML/ANE)
│   │   ├── FluidAudioEngine.swift       # Parakeet and others
│   │   └── ModelCatalog.swift           # JSON catalog of 30–40 models
│   ├── Localization.swift # AppLanguage (ru/en) + L("русский ключ") lookup table
│   ├── Insertion/        # text insertion: clipboard + CGEvent ⌘V
│   └── History/          # GRDB/SwiftData: records, audio files
├── Features/
│   ├── HUD/              # state machine + SwiftUI views for the states
│   └── Settings/         # tabs (incl. Onboarding) + ShortcutField (needs KeyboardShortcuts/Prefs)
└── DesignSystem/         # no app dependencies, no localization — plain strings in, pixels out
    ├── Tokens.swift      # colors, radii, fonts
    ├── Buttons.swift     # DSButton (5 variants), DSIconAction
    ├── Controls.swift    # AccentToggle, DSSegmentedControl, DSRadio
    ├── Dropdown.swift    # DesignDropdown + floating NSPanel list
    ├── Indicators.swift  # DSChip, DSProgressBar
    ├── Layout.swift      # SettingsSection, SettingRow, RowDivider, SectionLabel
    └── Modifiers.swift   # dsFieldStyle, hoverBackground, pointerCursor
```

## Key contracts

```swift
protocol TranscriptionEngine {
    var supportedModels: [ModelDescriptor] { get }
    func load(model: ModelDescriptor) async throws
    func unload()
    func transcribe(audio: AudioBuffer, options: TranscriptionOptions) async throws -> Transcript
}

struct ModelDescriptor: Codable, Identifiable {
    let id: String            // "openai_whisper-large-v3"
    let engine: EngineKind    // .whisperKit | .fluidAudio
    let displayName: String   // "Whisper Large v3"
    let sizeBytes: Int64
    let languages: LanguageSupport   // .multilingual(99) | .englishOnly | .european(25)
    let accuracy: Int         // 1–10 for the card
    let speed: Int            // 1–10
    let downloadSource: URL   // Hugging Face repo
    let tags: [ModelTag]      // .recommended, .quantized, .distil …
}
```

The catalog is a static JSON in the bundle (`ModelCatalog.json`) + the downloaded state on disk (`~/Library/Application Support/v0ca/models/`). The active model and the auto-unload timer live in `ModelManager` (actor).

## HUD state machine

```
hidden → recording → processing → done → hidden
            ↓ Esc        ↓ cancel
          hidden        hidden
```

A single `RecordingCoordinator` (actor / @Observable) owns the loop: hotkey → start audio → stop → transcription → post-processing (dictionary, space) → insertion → history.

## Text insertion

1. Save the current clipboard contents (optional).
2. Write the transcript to `NSPasteboard`.
3. Synthetic ⌘V via `CGEvent` (requires the Accessibility / Input Monitoring permission).
4. Restore the clipboard according to the "Clipboard handling" setting.

## Dependencies (SPM)

| Package | Purpose |
|---|---|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Whisper on CoreML/ANE, model downloads from HF, streaming |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | Parakeet TDT (25 European languages, ~110× RT), VAD |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | global hotkeys with a UI recorder |
| [GRDB](https://github.com/groue/GRDB.swift) | history (SQLite) |
| Sparkle (stage 4) | auto-updates |

## Permissions

- `NSMicrophoneUsageDescription` — recording.
- Accessibility (`AXIsProcessTrusted`) — synthetic ⌘V.
- App Sandbox: most likely disabled (CGEvent + Accessibility don't play well with the sandbox); distribution outside the App Store with notarization.
