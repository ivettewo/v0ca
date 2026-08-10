import AppKit

/// Recording start/finish sounds — toggled independently (Sound tab).
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
