import Foundation

struct HistoryRecord: Codable, Identifiable, Equatable {
    /// What produced the entry. One timeline holds all three: the filter on the
    /// History tab only hides rows, it doesn't switch between separate lists.
    enum Kind: String, Codable {
        case dictation
        case ask
        case screen
    }

    let id: UUID
    let date: Date
    let duration: Double // seconds; 0 for entries that have no audio
    /// The body of the row: the transcript for a dictation, the model's answer
    /// for the other two.
    var text: String
    var favorite: Bool
    /// WAV in the recordings folder. Nil when there is no audio — an answer from
    /// a model isn't a recording, and a screenshot is never written to disk.
    let fileName: String?
    let kind: Kind
    /// What was asked. Nil for a dictation, and for a screenshot sent in silence.
    let question: String?

    init(
        id: UUID,
        date: Date,
        duration: Double,
        text: String,
        favorite: Bool,
        fileName: String?,
        kind: Kind = .dictation,
        question: String? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.text = text
        self.favorite = favorite
        self.fileName = fileName
        self.kind = kind
        self.question = question
    }

    /// `kind`, `question` and an optional `fileName` came later. Synthesized
    /// decoding throws `keyNotFound` on the old shape, which would wipe the whole
    /// history — everything written before this is a dictation with audio.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(Double.self, forKey: .duration)
        text = try container.decode(String.self, forKey: .text)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .dictation
        question = try container.decodeIfPresent(String.self, forKey: .question)
    }

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
