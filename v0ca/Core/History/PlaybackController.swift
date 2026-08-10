import AVFoundation
import Observation

/// Player for history recordings: one recording at a time, progress for the bar.
@MainActor
@Observable
final class PlaybackController {
    private(set) var playingID: UUID?
    private(set) var progress: Double = 0 // 0…1
    /// Pause is a separate observable field: views don't track `player.isPlaying`,
    /// so the play/pause icon wasn't updating on pause/resume.
    private(set) var paused = false

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?

    func toggle(_ id: UUID, url: URL) {
        if playingID == id, let player {
            if player.isPlaying {
                player.pause()
                paused = true
            } else {
                player.play()
                paused = false
            }
            return
        }
        stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        player = newPlayer
        playingID = id
        paused = false
        newPlayer.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func isPlaying(_ id: UUID) -> Bool {
        playingID == id && !paused
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        playingID = nil
        paused = false
        progress = 0
    }

    private func tick() {
        guard let player else { return }
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        // Reached the end — reset.
        if !player.isPlaying, player.currentTime == 0 || player.currentTime >= player.duration - 0.05 {
            stop()
        }
    }
}
