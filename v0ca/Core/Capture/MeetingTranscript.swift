import Foundation
import Observation
import OSLog

/// One line of a conversation, as it will appear in the panel.
struct MeetingLine: Identifiable, Equatable {
    let id = UUID()
    let side: MeetingRecorder.Side
    /// When the words were said, not when they finished transcribing. Two sides
    /// transcribe at different speeds, and order has to come from the clock.
    let startedAt: Date
    var text: String
}

/// Turns tagged audio into a growing list of lines while the call is still
/// running: segments each side on its own, transcribes utterances one at a time,
/// and inserts each result at its rightful place in the timeline.
///
/// Step 2 of docs/modules/MEETING-BUILD.md.
@MainActor
@Observable
final class MeetingTranscript {
    private(set) var lines: [MeetingLine] = []
    /// What the conversation is called. Set in the panel before or during the
    /// call, and carried into the history when it ends.
    var title = ""
    /// Something is being transcribed right now — the panel shows this as
    /// "waiting for the next line".
    private(set) var isWorking = false

    /// Called with the whole conversation each time a line is added.
    @ObservationIgnored var onLine: (([MeetingLine]) -> Void)?

    @ObservationIgnored private let models: ModelManager
    @ObservationIgnored private var segmenters: [MeetingRecorder.Side: SpeechSegmenter] = [
        .me: SpeechSegmenter(),
        .them: SpeechSegmenter(),
    ]
    /// Utterances waiting for the engine. One engine, one at a time: two
    /// concurrent transcriptions on the same model are slower than two in a row.
    @ObservationIgnored private var pending: [(side: MeetingRecorder.Side, utterance: SpeechSegmenter.Utterance)] = []
    @ObservationIgnored private var draining = false
    @ObservationIgnored private let log = Logger(category: "MeetingTranscript")

    init(models: ModelManager) {
        self.models = models
    }

    func reset() {
        lines = []
        title = ""
        onLine = nil
        pending = []
        segmenters = [.me: SpeechSegmenter(), .them: SpeechSegmenter()]
    }

    func accept(_ chunk: MeetingRecorder.Chunk) {
        guard var segmenter = segmenters[chunk.side] else { return }
        let finished = segmenter.accept(chunk.samples, at: chunk.at)
        segmenters[chunk.side] = segmenter
        guard let finished else { return }
        enqueue(finished, side: chunk.side)
    }

    /// The call ended: whatever was mid-sentence still counts.
    func flush() {
        for side in segmenters.keys {
            guard var segmenter = segmenters[side] else { continue }
            let tail = segmenter.finish()
            segmenters[side] = segmenter
            if let tail {
                enqueue(tail, side: side)
            }
        }
    }

    private func enqueue(_ utterance: SpeechSegmenter.Utterance, side: MeetingRecorder.Side) {
        pending.append((side, utterance))
        drain()
    }

    private func drain() {
        guard !draining, !pending.isEmpty else { return }
        draining = true
        isWorking = true

        Task {
            defer {
                draining = false
                isWorking = false
                // Anything that arrived while the engine was busy.
                if !pending.isEmpty { drain() }
            }
            while !pending.isEmpty {
                let next = pending.removeFirst()
                await transcribe(next.utterance, side: next.side)
            }
        }
    }

    private func transcribe(_ utterance: SpeechSegmenter.Utterance, side: MeetingRecorder.Side) async {
        do {
            let text = try await models.transcribe(utterance.samples, options: .fromPrefs)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !Self.isHallucination(trimmed) else { return }
            let line = MeetingLine(side: side, startedAt: utterance.startedAt, text: trimmed)
            insert(line)
            MeetingCaptureProbe.shared.note(line)
            onLine?(lines)
        } catch {
            log.error("Реплика не распознана: \(error)")
        }
    }

    /// Waits for the queue to empty — the call ended, but the last lines may
    /// still be in the engine.
    func waitForIdle() async {
        while draining || !pending.isEmpty {
            try? await Task.sleep(for: .milliseconds(120))
        }
    }

    /// Sorted insert: a slow side must not have its line land after words that
    /// were spoken later.
    private func insert(_ line: MeetingLine) {
        let index = lines.firstIndex { $0.startedAt > line.startedAt } ?? lines.count
        lines.insert(line, at: index)
    }

    /// Whisper fills silence with the phrases it saw most in training —
    /// subtitle credits, mostly. On a two-second segment this happens often
    /// enough that letting it through would put junk in the transcript.
    private static let hallucinations = [
        "продолжение следует", "субтитры", "редактор субтитров",
        "thank you for watching", "thanks for watching", "subtitles by",
    ]

    private static func isHallucination(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return hallucinations.contains { lowered.contains($0) }
    }
}
