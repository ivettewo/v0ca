import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Start / stop recording. Defaults to ⌥ Space (from the mockup), editable in Settings.
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
    /// Cancel recording. Enabled only while recording/transcribing, to avoid capturing Esc system-wide.
    static let cancelRecording = Self("cancelRecording", default: .init(.escape))

    /// Switching the bar mode without opening the menu.
    static let modeDictation = Self("modeDictation", default: .init(.one, modifiers: [.command]))
    static let modeAsk = Self("modeAsk", default: .init(.two, modifiers: [.command]))
    static let modeScreen = Self("modeScreen", default: .init(.three, modifiers: [.command]))
    static let modeMeeting = Self("modeMeeting", default: .init(.four, modifiers: [.command]))

    /// The shortcut that switches to a given mode — one place, so the menu hint
    /// and the registration can't drift apart.
    static func mode(_ mode: Prefs.HUDMode) -> Self {
        switch mode {
        case .dictation: .modeDictation
        case .ask: .modeAsk
        case .screen: .modeScreen
        case .meeting: .modeMeeting
        }
    }
}
