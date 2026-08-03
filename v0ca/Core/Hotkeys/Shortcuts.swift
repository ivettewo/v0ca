import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Начать / остановить запись. По умолчанию ⌥ Space (из макета), редактируется в настройках.
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
    /// Отменить запись. Включается только пока идёт запись/расшифровка, чтобы не перехватывать Esc системно.
    static let cancelRecording = Self("cancelRecording", default: .init(.escape))
}
