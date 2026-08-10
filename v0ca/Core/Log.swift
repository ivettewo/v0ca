import OSLog

extension Logger {
    /// App logger: a single subsystem, only the category is set by the caller.
    ///     private let log = Logger(category: "ModelManager")
    /// View with: `log show --predicate 'subsystem == "com.v0ca.app"'`.
    init(category: String) {
        self.init(subsystem: "com.v0ca.app", category: category)
    }
}
