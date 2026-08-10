import Foundation

struct HistoryRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let duration: Double // seconds
    var text: String
    var favorite: Bool
    let fileName: String // WAV in the recordings folder

    var dateLabel: String {
        Self.dateFormatter.string(from: date)
    }

    var durationLabel: String {
        let total = Int(duration.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy · HH:mm"
        return formatter
    }()
}
