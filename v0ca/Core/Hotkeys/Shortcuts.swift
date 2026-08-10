import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Start / stop recording. Defaults to ⌥ Space (from the mockup), editable in Settings.
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
    /// Cancel recording. Enabled only while recording/transcribing, to avoid capturing Esc system-wide.
    static let cancelRecording = Self("cancelRecording", default: .init(.escape))
}
