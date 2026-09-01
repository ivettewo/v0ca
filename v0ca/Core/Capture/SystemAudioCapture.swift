import AVFoundation
import OSLog
import ScreenCaptureKit

/// What the machine plays — the other side of a call. The microphone is you;
/// this is everyone else, and the split is what lets the meeting panel label
/// lines without guessing who is speaking.
///
/// Uses the Screen Recording permission the "Screen" mode already asks for: on
/// macOS, system audio arrives through ScreenCaptureKit whether or not any video
/// is wanted. None of it is written to disk.
final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    enum Failure: Error {
        case noPermission
        case noDisplay
    }

    /// Called on a background queue with 16 kHz mono samples, in arrival order.
    var onSamples: (@Sendable ([Float]) -> Void)?

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.v0ca.system-audio")
    private let log = Logger(category: "SystemAudioCapture")

    var isRunning: Bool { stream != nil }

    func start() async throws {
        guard CGPreflightScreenCaptureAccess() else { throw Failure.noPermission }

        // A filter needs a display even when only the audio is wanted.
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false
        )
        guard let display = content.displays.first else { throw Failure.noDisplay }

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        // Our own sounds — the start chime, a played-back recording — are not
        // part of the conversation.
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 1
        // The video side can't be switched off, so it is squeezed to nothing:
        // two pixels once a second costs less than a rounding error.
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(
            filter: SCContentFilter(display: display, excludingWindows: []),
            configuration: configuration,
            delegate: self
        )
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
        log.info("Системный звук: захват начат")
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
        log.info("Системный звук: захват остановлен")
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio, let samples = Self.mono16k(from: sampleBuffer) else { return }
        onSamples?(samples)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("Системный звук оборвался: \(error)")
        self.stream = nil
    }

    /// `CMSampleBuffer` (Float32, 48 kHz) → 16 kHz mono floats.
    ///
    /// Reads the raw floats out of the block buffer and decimates by index
    /// rather than going through `AVAudioConverter`, which throws on some of the
    /// formats this delivers. Nearest-sample decimation is crude, but speech at
    /// 16 kHz is what the engine wants anyway.
    private static func mono16k(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
              asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              asbd.mBitsPerChannel == 32
        else { return nil }

        let channels = Int(asbd.mChannelsPerFrame)
        guard channels > 0 else { return nil }
        let inputRate = asbd.mSampleRate > 0 ? asbd.mSampleRate : 48_000

        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(
            block, atOffset: 0, lengthAtOffsetOut: nil,
            totalLengthOut: &length, dataPointerOut: &pointer
        ) == kCMBlockBufferNoErr, let pointer else { return nil }

        let floatCount = length / MemoryLayout<Float>.size
        guard floatCount > 0 else { return nil }
        let floats = UnsafeRawPointer(pointer).bindMemory(to: Float.self, capacity: floatCount)

        let frames = floatCount / channels
        let step = max(1, Int((inputRate / 16_000).rounded()))
        var output: [Float] = []
        output.reserveCapacity(frames / step + 1)

        var frame = 0
        while frame < frames {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += floats[frame * channels + channel]
            }
            output.append(sum / Float(channels))
            frame += step
        }
        return output
    }
}
