import Foundation

/// Cuts a stream of audio chunks into finished utterances.
///
/// Deliberately crude: loudness against a threshold, a run of quiet buffers ends
/// the line. Real voice activity detection would be better at telling speech from
/// a door slam, and worse at everything else that matters here — it would cost
/// latency and a model, and this runs on two streams at once for an hour.
///
/// One segmenter per side: the two sides talk over each other, and a shared one
/// would splice them into a single line.
struct SpeechSegmenter {
    /// Loud enough to be speech. From settings — the mockup calls it the
    /// trigger threshold.
    var threshold: Float
    /// Quiet buffers in a row that end an utterance. At ~10 buffers a second
    /// this is roughly a second of silence.
    var silenceToEnd = 10
    /// Below this an utterance is noise, not words.
    var minSamples = 8_000
    /// Continuous speech is cut here so the transcript keeps up rather than
    /// waiting for a pause that may never come. The mockup calls it the
    /// segmentation window.
    var maxSamples: Int

    /// Reads both knobs from settings once, at the start of a call: changing
    /// them mid-conversation would move the goalposts between two lines.
    @MainActor
    init() {
        threshold = Float(Prefs.meetingThreshold)
        maxSamples = Int(Prefs.meetingWindowSeconds * 16_000)
    }

    private var buffer: [Float] = []
    private var quietRun = 0
    private var heardSpeech = false
    /// When the current utterance began — the panel orders lines by this, not by
    /// when transcription happened to finish.
    private var startedAt: Date?

    /// Loudness of a chunk. Lives here rather than on the recorder: the
    /// segmenter runs off the main actor, where the recorder isn't reachable.
    static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return (sum / Float(samples.count)).squareRoot()
    }

    struct Utterance {
        let samples: [Float]
        let startedAt: Date
    }

    /// Feeds one chunk in and returns an utterance if this chunk ended one.
    mutating func accept(_ samples: [Float], at time: Date) -> Utterance? {
        let level = Self.rms(samples)

        if level >= threshold {
            if !heardSpeech {
                startedAt = time
                heardSpeech = true
            }
            quietRun = 0
            buffer.append(contentsOf: samples)
            return buffer.count >= maxSamples ? flush() : nil
        }

        guard heardSpeech else { return nil }
        // Silence inside speech is part of the line — a pause between words is
        // not the end of a sentence. It only counts towards ending it.
        buffer.append(contentsOf: samples)
        quietRun += 1
        return quietRun >= silenceToEnd ? flush() : nil
    }

    /// Ends whatever is in progress — the call stopped mid-sentence.
    mutating func finish() -> Utterance? {
        flush()
    }

    private mutating func flush() -> Utterance? {
        defer {
            buffer.removeAll(keepingCapacity: true)
            quietRun = 0
            heardSpeech = false
            startedAt = nil
        }
        guard buffer.count >= minSamples, let startedAt else { return nil }
        return Utterance(samples: buffer, startedAt: startedAt)
    }
}
