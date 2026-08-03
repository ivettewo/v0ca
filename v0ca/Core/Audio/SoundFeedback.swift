import AppKit

/// Звуки начала и завершения записи — включаются раздельно (вкладка «Звук»).
enum SoundFeedback {
    static func recordStart() {
        guard Prefs.soundStart else { return }
        NSSound(named: "Tink")?.play()
    }

    static func recordDone() {
        guard Prefs.soundDone else { return }
        NSSound(named: "Pop")?.play()
    }
}
