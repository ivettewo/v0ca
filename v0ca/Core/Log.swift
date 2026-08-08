import OSLog

extension Logger {
    /// Логгер приложения: единая подсистема, снаружи задаётся только категория.
    ///     private let log = Logger(category: "ModelManager")
    /// Смотреть: `log show --predicate 'subsystem == "com.v0ca.app"'`.
    init(category: String) {
        self.init(subsystem: "com.v0ca.app", category: category)
    }
}
