import AVFoundation
import Observation

/// Плеер записей истории: одна запись за раз, прогресс для полосы.
@MainActor
@Observable
final class PlaybackController {
    private(set) var playingID: UUID?
    private(set) var progress: Double = 0 // 0…1

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?

    func toggle(_ id: UUID, url: URL) {
        if playingID == id, let player {
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
            return
        }
        stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        player = newPlayer
        playingID = id
        newPlayer.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func isPlaying(_ id: UUID) -> Bool {
        playingID == id && player?.isPlaying == true
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        playingID = nil
        progress = 0
    }

    private func tick() {
        guard let player else { return }
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        // Дошли до конца — сбрасываемся.
        if !player.isPlaying, player.currentTime == 0 || player.currentTime >= player.duration - 0.05 {
            stop()
        }
    }
}
