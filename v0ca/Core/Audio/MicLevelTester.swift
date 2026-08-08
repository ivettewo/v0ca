import AVFoundation
import Observation
import OSLog

/// Живой индикатор уровня микрофона для вкладки «Звук».
/// AVCaptureSession, как и запись: без агрегатных устройств и без блокировки UI.
@MainActor
@Observable
final class MicLevelTester: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private(set) var level: Float = 0
    private(set) var isRunning = false
    private(set) var errorText: String?

    @ObservationIgnored private let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCaptureAudioDataOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.v0ca.mic-tester")
    @ObservationIgnored private let log = Logger(category: "MicLevelTester")

    @ObservationIgnored private var isStarting = false

    func start() {
        guard !isRunning, !isStarting else { return }
        isStarting = true
        errorText = nil
        Task {
            defer { isStarting = false }
            guard await AudioRecorder.requestMicAccess() == .granted else {
                errorText = "Нет доступа к микрофону — включите во вкладке «Разрешения»"
                return
            }
            guard let device = AudioRecorder.selectedDevice() else {
                errorText = "Микрофон не найден"
                return
            }
            do {
                session.beginConfiguration()
                session.inputs.forEach { session.removeInput($0) }
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                output.audioSettings = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsNonInterleaved: false,
                    AVLinearPCMIsBigEndianKey: false,
                ]
                output.setSampleBufferDelegate(self, queue: queue)
                if !session.outputs.contains(output), session.canAddOutput(output) {
                    session.addOutput(output)
                }
                session.commitConfiguration()
                session.startRunning()
                isRunning = true
                log.info("Тест микрофона запущен: \(device.localizedName, privacy: .public)")
            } catch {
                errorText = "Не удалось запустить: \(error.localizedDescription)"
                log.error("Тест микрофона: \(error)")
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        session.stopRunning()
        isRunning = false
        level = 0
    }

    func restart() {
        stop()
        start()
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let chunk = AudioConvert.floatMono(from: sampleBuffer), !chunk.isEmpty else { return }
        var sum: Float = 0
        for sample in chunk {
            sum += sample * sample
        }
        let rms = (sum / Float(chunk.count)).squareRoot()
        let scaled = min(rms * 12, 1)
        Task { @MainActor in
            self.level = scaled
        }
    }
}
