import AVFoundation
import OSLog

/// Records the microphone via an AVCaptureSession bound to a specific device.
/// Unlike AVAudioEngine, it does NOT create an aggregate device and never touches output —
/// AirPods stay in stereo, and the format is Whisper-ready out of the box: 16 kHz, mono, Float32.
final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "com.v0ca.mic-capture")
    private var samples: [Float] = []
    private let lock = NSLock()
    private let log = Logger(category: "AudioRecorder")

    /// RMS level for the HUD waveform, called on the main thread.
    var onLevel: ((Float) -> Void)?
    /// Every chunk as it arrives, on the capture queue. Dictation takes the whole
    /// recording at the end; the meeting panel needs it while it is still going,
    /// and a second capture session on the same device is not an option.
    var onSamples: (@Sendable ([Float]) -> Void)?

    private static let whisperSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    enum MicAccess {
        case granted
        case denied
    }

    /// Distinguishes "not asked yet" (show the system prompt) from "denied"
    /// (the prompt won't appear again — System Settings is the only way).
    static func requestMicAccess() async -> MicAccess {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio) ? .granted : .denied
        default:
            return .denied
        }
    }

    /// The microphone selected in settings (by UID) or the system default.
    static func selectedDevice() -> AVCaptureDevice? {
        let uid = UserDefaults.standard.string(forKey: Prefs.Key.inputDeviceUID) ?? ""
        if !uid.isEmpty, let device = AVCaptureDevice(uniqueID: uid) {
            return device
        }
        return AVCaptureDevice.default(for: .audio)
    }

    func start() throws {
        lock.lock()
        samples.removeAll()
        lock.unlock()

        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        guard let device = Self.selectedDevice() else {
            session.commitConfiguration()
            throw RecorderError.deviceUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        output.audioSettings = Self.whisperSettings
        output.setSampleBufferDelegate(self, queue: queue)
        if !session.outputs.contains(output), session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        session.startRunning()
        log.info("Запись начата: \(device.localizedName, privacy: .public)")
    }

    @discardableResult
    func stop() -> [Float] {
        session.stopRunning()
        lock.lock()
        defer { lock.unlock() }
        log.info("Запись остановлена: \(self.samples.count) сэмплов")
        return samples
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let chunk = AudioConvert.floatMono(from: sampleBuffer), !chunk.isEmpty else { return }
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
        onSamples?(chunk)

        var sum: Float = 0
        for sample in chunk {
            sum += sample * sample
        }
        let rms = (sum / Float(chunk.count)).squareRoot()
        let level = min(rms * 12, 1)
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }
    }

    enum RecorderError: Error {
        case deviceUnavailable
    }
}
