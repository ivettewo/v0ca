import Foundation

/// Чтение/запись WAV 16 kHz mono 16-bit PCM — формат хранения записей истории.
enum WavFile {
    static let sampleRate = 16_000

    static func write(samples: [Float], to url: URL) throws {
        let pcm = samples.map { sample -> Int16 in
            let clamped = max(-1, min(1, sample))
            return Int16(clamped * Float(Int16.max))
        }
        let dataSize = pcm.count * 2
        var header = Data()
        func append(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { header.append(contentsOf: $0) } }

        header.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + dataSize))
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        append(16)
        append16(1) // PCM
        append16(1) // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2)) // byte rate
        append16(2) // block align
        append16(16) // bits
        header.append(contentsOf: "data".utf8)
        append(UInt32(dataSize))

        var data = header
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        try data.write(to: url)
    }

    static func read(from url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        // ищем чанк "data" (после 12-байтового RIFF-заголовка)
        var offset = 12
        while offset + 8 <= data.count {
            let id = String(bytes: data[offset..<offset + 4], encoding: .ascii) ?? ""
            let size = data[offset + 4..<offset + 8].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
            if id == "data" {
                let start = offset + 8
                let end = min(start + Int(size), data.count)
                let bytes = data[start..<end]
                var samples = [Float]()
                samples.reserveCapacity(bytes.count / 2)
                var i = bytes.startIndex
                while i + 1 < bytes.endIndex {
                    let value = Int16(littleEndian: data[i..<i + 2].withUnsafeBytes { $0.loadUnaligned(as: Int16.self) })
                    samples.append(Float(value) / Float(Int16.max))
                    i += 2
                }
                return samples
            }
            offset += 8 + Int(size) + (Int(size) % 2)
        }
        throw WavError.noDataChunk
    }

    enum WavError: Error {
        case noDataChunk
    }
}
