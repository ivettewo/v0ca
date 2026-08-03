import CoreMedia

enum AudioConvert {
    /// Читает Float32-моно сэмплы из CMSampleBuffer.
    /// Буфер уже приведён к нужному формату через audioSettings у AVCaptureAudioDataOutput.
    static func floatMono(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var length = 0
        var dataPointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer
        ) == kCMBlockBufferNoErr, let dataPointer else { return nil }

        let count = length / MemoryLayout<Float>.size
        guard count > 0 else { return nil }
        let floats = UnsafeRawPointer(dataPointer).bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: floats, count: count))
    }
}
