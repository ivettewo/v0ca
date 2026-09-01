import AVFoundation
import Foundation
import Observation
import OSLog

/// Both sides of a call as one stream of tagged chunks: the microphone is you,
/// what the machine plays is everyone else. The side comes from the source, so
/// nothing has to be guessed from the audio — which is why the panel can label
/// lines and still promise it does not identify speakers.
///
/// Step 1 of docs/modules/MEETING-BUILD.md: capture only. Segmentation into
/// lines and transcription come next; nothing here writes to disk.
@MainActor
@Observable
final class MeetingRecorder {
    enum Side: String {
        /// The microphone.
        case me
        /// What the machine plays.
        case them
    }

    struct Chunk {
        let side: Side
        /// When the chunk started, taken on arrival. Ordering across two
        /// independent sources can only come from a clock.
        let at: Date
        let samples: [Float]
    }

    enum Failure: Error {
        /// The microphone is fine but the system side needs Screen Recording.
        case noScreenPermission
    }

    /// True while both sources are live. Observed, so an indicator can follow it:
    /// recording a conversation must never be invisible.
    private(set) var isRunning = false

    /// Every chunk from either side, on the main actor and in arrival order.
    @ObservationIgnored var onChunk: ((Chunk) -> Void)?

    @ObservationIgnored private let microphone = AudioRecorder()
    @ObservationIgnored private let system = SystemAudioCapture()
    @ObservationIgnored private let log = Logger(category: "MeetingRecorder")

    /// Counters for the log — the only way to tell "silent" from "not arriving"
    /// before there is a panel to look at.
    @ObservationIgnored private var counts: [Side: Int] = [:]

    func start() async throws {
        guard !isRunning else { return }
        guard ScreenCapture.hasPermission else {
            ScreenCapture.requestPermission()
            throw Failure.noScreenPermission
        }

        counts = [:]
        microphone.onSamples = { [weak self] samples in
            Task { @MainActor in self?.emit(.me, samples) }
        }
        system.onSamples = { [weak self] samples in
            Task { @MainActor in self?.emit(.them, samples) }
        }

        try microphone.start()
        do {
            try await system.start()
        } catch {
            // One-sided capture would silently record only the user, which is
            // the opposite of what this is for.
            _ = microphone.stop()
            microphone.onSamples = nil
            throw error
        }

        isRunning = true
        log.info("Митинг: захват начат — микрофон и системный звук")
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        _ = microphone.stop()
        microphone.onSamples = nil
        await system.stop()
        system.onSamples = nil
        log.info("""
        Митинг: захват остановлен — \
        я \(self.counts[.me] ?? 0, privacy: .public) кусков, \
        собеседник \(self.counts[.them] ?? 0, privacy: .public)
        """)
    }

    private func emit(_ side: Side, _ samples: [Float]) {
        guard isRunning || side == .me else { return }
        counts[side, default: 0] += 1
        onChunk?(Chunk(side: side, at: Date(), samples: samples))
    }

}
