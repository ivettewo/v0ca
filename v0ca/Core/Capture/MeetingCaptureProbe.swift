import Foundation
import OSLog

/// Log-only sink for steps 1–2 of the meeting module: proves both sides arrive,
/// how loud each one is, and — once lines start coming back — what was heard,
/// before there is anything to display them in.
///
/// Prints a line a second rather than one per chunk — audio arrives dozens of
/// times a second, and a log that fast is a log nobody reads. Deleted once the
/// panel exists (docs/modules/MEETING-BUILD.md).
@MainActor
final class MeetingCaptureProbe {
    static let shared = MeetingCaptureProbe()

    private var counts: [MeetingRecorder.Side: Int] = [:]
    private var peaks: [MeetingRecorder.Side: Float] = [:]
    private var lastReport = Date.distantPast
    private let log = Logger(category: "MeetingCapture")

    /// A finished line, logged as soon as it is recognized.
    func note(_ line: MeetingLine) {
        log.info("""
        \(line.side == .me ? "я" : "собеседник", privacy: .public): \
        \(line.text, privacy: .public)
        """)
    }

    func note(_ chunk: MeetingRecorder.Chunk) {
        counts[chunk.side, default: 0] += 1
        let level = SpeechSegmenter.rms(chunk.samples)
        peaks[chunk.side] = max(peaks[chunk.side] ?? 0, level)

        guard Date().timeIntervalSince(lastReport) >= 1 else { return }
        lastReport = Date()
        log.info("""
        я: \(self.counts[.me] ?? 0, privacy: .public) кусков, пик \
        \(String(format: "%.3f", self.peaks[.me] ?? 0), privacy: .public) · \
        собеседник: \(self.counts[.them] ?? 0, privacy: .public) кусков, пик \
        \(String(format: "%.3f", self.peaks[.them] ?? 0), privacy: .public)
        """)
        counts = [:]
        peaks = [:]
    }
}
