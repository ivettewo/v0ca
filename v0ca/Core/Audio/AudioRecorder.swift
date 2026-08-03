import AVFoundation
import OSLog

/// Пишет микрофон через AVCaptureSession, привязанную к конкретному устройству.
/// В отличие от AVAudioEngine, НЕ создаёт агрегатное устройство и не трогает выход —
/// AirPods остаются в стерео, а формат сразу под Whisper: 16 кГц, моно, Float32.
final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "com.v0ca.mic-capture")
    private var samples: [Float] = []
    private let lock = NSLock()
    private let log = Logger(subsystem: "com.v0ca.app", category: "AudioRecorder")

    /// RMS-уровень для волны HUD, вызывается на главном потоке.
    var onLevel: ((Float) -> Void)?

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

    /// Различает «ещё не спрашивали» (показываем системный запрос) и «отклонено»
    /// (запрос больше не покажется — только системные настройки).
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

    /// Выбранный микрофон (по UID из настроек) или системный по умолчанию.
    static func selectedDevice() -> AVCaptureDevice? {
        let uid = UserDefaults.standard.string(forKey: AudioDevices.selectedUIDKey) ?? ""
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
