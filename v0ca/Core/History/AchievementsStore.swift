import Foundation
import KeyboardShortcuts
import Observation
import OSLog

/// One row on the achievements shelf. Built on the fly from StatsStore and the
/// current settings — only the handful of things the app would otherwise forget
/// are persisted (see `AchievementsStore.Flag`).
struct Achievement: Identifiable {
    enum Group: String, CaseIterable {
        case volume, dictations, streak, records, saved, rhythm
        case questions, screens, asking, providers
        case mastery

        /// Section header. Russian base string — the key for `L()`.
        var title: String {
            switch self {
            case .volume: "Объём"
            case .dictations: "Диктовки"
            case .streak: "Серия"
            case .records: "Рекорды за день"
            case .saved: "Сэкономленное время"
            case .rhythm: "Ритм"
            case .questions: "Вопросы"
            case .screens: "Снимки экрана"
            case .asking: "Как спрашиваешь"
            case .providers: "Провайдеры"
            case .mastery: "Освоение"
            }
        }
    }

    let id: String
    let group: Group
    let title: String
    /// Caption under the title: what to do while locked, what was done once unlocked.
    let caption: String
    let icon: String
    /// Progress towards the goal, 0…1.
    let fraction: Double
    /// Short "12/30" for the middle of the ring. Nil for all-or-nothing
    /// achievements — there is no progress to show, so the ring holds a muted icon.
    let progressLabel: String?

    var unlocked: Bool { fraction >= 1 }
}

/// Achievement flags that can't be recovered from the current state.
/// Everything else — a changed hotkey, a second model, a picked microphone —
/// is derived from settings, so a long-time user doesn't open the tab to an empty shelf.
@MainActor
@Observable
final class AchievementsStore {
    enum Flag: String, Codable, CaseIterable {
        case playback
        case retranscribe
        case favorite
        case engineWhisperKit
        case engineFluidAudio
        /// A screenshot sent without saying anything.
        case silentScreen
        /// Backed out during the countdown, before the question left the Mac.
        case askCancelled
        /// Asked the same question again.
        case regenerated
        /// Waited out a long answer instead of giving up.
        case patientAnswer
        // One per provider that has actually answered something.
        case providerOpenAI
        case providerAnthropic
        case providerXai
        case providerGoogle
        case providerQwen
    }

    /// Which flag marks "this provider has answered".
    static func flag(forProvider id: String) -> Flag? {
        switch id {
        case "openai": .providerOpenAI
        case "anthropic": .providerAnthropic
        case "xai": .providerXai
        case "google": .providerGoogle
        case "qwen": .providerQwen
        default: nil
        }
    }

    private(set) var flags: Set<Flag> = []

    @ObservationIgnored private let log = Logger(category: "AchievementsStore")

    private static var fileURL: URL {
        HistoryStore.baseFolder.appendingPathComponent("achievements.json")
    }

    init() {
        load()
    }

    func mark(_ flag: Flag) {
        guard !flags.contains(flag) else { return }
        flags.insert(flag)
        save()
    }

    func mark(engine: EngineKind) {
        mark(engine == .whisperKit ? .engineWhisperKit : .engineFluidAudio)
    }

    // MARK: - Catalog

    /// The full shelf, in display order. Progress is recomputed on every read —
    /// cheap enough, and it keeps the tab in sync with stats without extra plumbing.
    func all(stats: StatsStore, models: ModelManager, history: HistoryStore) -> [Achievement] {
        volume(stats) + dictations(stats) + streak(stats) + records(stats)
            + saved(stats) + rhythm(stats) + questions(stats) + screens(stats)
            + asking(stats) + providers() + mastery(models: models, history: history)
    }

    private func volume(_ stats: StatsStore) -> [Achievement] {
        let total = stats.totalWords
        let steps: [(String, String, Int, String)] = [
            ("volume.first", "Первое слово", 1, "star"),
            ("volume.1k", "Разговорился", 1_000, "text.bubble"),
            ("volume.10k", "Десять тысяч", 10_000, "text.alignleft"),
            ("volume.50k", "Роман", 50_000, "book"),
            ("volume.100k", "Полка", 100_000, "books.vertical"),
            ("volume.500k", "Собрание сочинений", 500_000, "building.columns"),
        ]
        return steps.map { id, title, goal, icon in
            counted(
                id: id, group: .volume, title: title, icon: icon,
                value: id == "volume.first" ? stats.totalDictations : total, goal: goal,
                caption: id == "volume.first"
                    ? L("Продиктуйте что-нибудь в первый раз")
                    : L("Расшифровать %@ слов", Self.grouped(goal))
            )
        }
    }

    private func dictations(_ stats: StatsStore) -> [Achievement] {
        let steps: [(String, String, Int, String)] = [
            ("dictations.10", "Разминка", 10, "figure.walk"),
            ("dictations.100", "Сотня", 100, "figure.run"),
            ("dictations.500", "Пятьсот", 500, "flame"),
            ("dictations.1000", "Тысяча", 1_000, "medal"),
            ("dictations.5000", "Пять тысяч", 5_000, "trophy"),
        ]
        return steps.map { id, title, goal, icon in
            counted(
                id: id, group: .dictations, title: title, icon: icon,
                value: stats.totalDictations, goal: goal,
                caption: L("Сделать %@ диктовок", Self.grouped(goal))
            )
        }
    }

    private func streak(_ stats: StatsStore) -> [Achievement] {
        let steps: [(String, String, Int, String)] = [
            ("streak.3", "Три дня", 3, "flame"),
            ("streak.7", "Неделя", 7, "calendar"),
            ("streak.30", "Месяц", 30, "calendar.badge.clock"),
            ("streak.100", "Сто дней", 100, "seal"),
            ("streak.365", "Год", 365, "crown"),
        ]
        return steps.map { id, title, goal, icon in
            counted(
                id: id, group: .streak, title: title, icon: icon,
                value: stats.streakDays, goal: goal,
                caption: L("Диктовать %@ дней подряд", Self.grouped(goal))
            )
        }
    }

    private func records(_ stats: StatsStore) -> [Achievement] {
        [
            counted(
                id: "records.words.day", group: .records, title: "Продуктивный день",
                icon: "sun.max", value: stats.bestWordsInDay, goal: 1_000,
                caption: L("1 000 слов за сутки")
            ),
            counted(
                id: "records.dictations.day", group: .records, title: "Без остановки",
                icon: "bolt", value: stats.bestDictationsInDay, goal: 50,
                caption: L("50 диктовок за сутки")
            ),
            counted(
                id: "records.monologue", group: .records, title: "Монолог",
                icon: "quote.bubble", value: stats.bestWordsInDictation, goal: 300,
                caption: L("300 слов за одну диктовку")
            ),
            counted(
                id: "records.long.monologue", group: .records, title: "Длинный монолог",
                icon: "text.quote", value: stats.bestWordsInDictation, goal: 1_000,
                caption: L("1 000 слов за одну диктовку")
            ),
        ]
    }

    private func saved(_ stats: StatsStore) -> [Achievement] {
        let savedHours = stats.savedSeconds / 3600
        let spokenHours = stats.totalSeconds / 3600
        let steps: [(String, String, Double, Double, String, String)] = [
            ("saved.1h", "Час свободы", savedHours, 1, "clock", "Сэкономить час против набора"),
            ("saved.8h", "Рабочий день", savedHours, 8, "briefcase", "Сэкономить рабочий день"),
            ("saved.40h", "Рабочая неделя", savedHours, 40, "calendar.badge.checkmark",
             "Сэкономить рабочую неделю"),
            ("saved.24h.spoken", "Сутки речи", spokenHours, 24, "waveform",
             "Наговорить 24 часа"),
        ]
        return steps.map { id, title, value, goal, icon, hint in
            Achievement(
                id: id, group: .saved, title: title,
                caption: value >= goal ? L("%@ ч — выполнено", Self.hours(value)) : L(hint),
                icon: icon,
                fraction: min(1, value / goal),
                progressLabel: value >= goal ? nil : Self.hours(value)
            )
        }
    }

    private func rhythm(_ stats: StatsStore) -> [Achievement] {
        [
            flagged(
                id: "rhythm.early", group: .rhythm, title: "Жаворонок", icon: "sunrise",
                done: stats.hasEarlyBird, caption: L("Продиктовать между 05:00 и 08:00")
            ),
            flagged(
                id: "rhythm.night", group: .rhythm, title: "Сова", icon: "moon.stars",
                done: stats.hasNightOwl, caption: L("Продиктовать между 00:00 и 04:00")
            ),
            flagged(
                id: "rhythm.weekend", group: .rhythm, title: "Выходной", icon: "beach.umbrella",
                done: stats.hasWeekend, caption: L("Продиктовать в субботу или воскресенье")
            ),
            Achievement(
                id: "rhythm.pace", group: .rhythm, title: "Скороговорка",
                caption: stats.bestWordsPerMinute >= 150
                    ? L("Лучший темп — %@ слов в минуту", "\(Int(stats.bestWordsPerMinute))")
                    : L("Продиктовать быстрее 150 слов в минуту"),
                icon: "hare",
                fraction: min(1, stats.bestWordsPerMinute / 150),
                progressLabel: stats.bestWordsPerMinute >= 150
                    ? nil : "\(Int(stats.bestWordsPerMinute))"
            ),
        ]
    }

    private func questions(_ stats: StatsStore) -> [Achievement] {
        let steps: [(String, String, Int, String)] = [
            ("ask.1", "Первый вопрос", 1, "bubble.left"),
            ("ask.10", "Любопытный", 10, "questionmark.bubble"),
            ("ask.100", "Собеседник", 100, "bubble.left.and.bubble.right"),
            ("ask.500", "Не отстанет", 500, "text.bubble"),
        ]
        return steps.map { id, title, goal, icon in
            counted(
                id: id, group: .questions, title: title, icon: icon,
                value: stats.totalAsks, goal: goal,
                caption: L("Задать %@ вопросов голосом", Self.grouped(goal))
            )
        }
    }

    private func screens(_ stats: StatsStore) -> [Achievement] {
        let steps: [(String, String, Int, String)] = [
            ("screen.1", "Первый снимок", 1, "camera.viewfinder"),
            ("screen.25", "Насмотренный", 25, "display"),
            ("screen.100", "Сто экранов", 100, "rectangle.on.rectangle"),
        ]
        return steps.map { id, title, goal, icon in
            counted(
                id: id, group: .screens, title: title, icon: icon,
                value: stats.totalScreens, goal: goal,
                caption: L("Отправить %@ снимков экрана", Self.grouped(goal))
            )
        }
    }

    private func asking(_ stats: StatsStore) -> [Achievement] {
        [
            flagged(
                id: "asking.both", group: .asking, title: "Оба режима", icon: "arrow.triangle.swap",
                done: stats.totalAsks > 0 && stats.totalScreens > 0,
                caption: L("Спросить и голосом, и по экрану")
            ),
            flagged(
                id: "asking.silent", group: .asking, title: "Молча", icon: "camera",
                done: flags.contains(.silentScreen),
                caption: L("Отправить снимок, ничего не сказав")
            ),
            counted(
                id: "asking.long", group: .asking, title: "Развёрнутый вопрос", icon: "text.alignleft",
                value: stats.bestAskWords, goal: 100,
                caption: L("Задать вопрос длиннее 100 слов")
            ),
            flagged(
                id: "asking.cancelled", group: .asking, title: "Передумал", icon: "arrow.uturn.left",
                done: flags.contains(.askCancelled),
                caption: L("Отменить вопрос во время отсчёта")
            ),
            flagged(
                id: "asking.again", group: .asking, title: "Не устроило", icon: "arrow.clockwise",
                done: flags.contains(.regenerated),
                caption: L("Перегенерировать ответ")
            ),
            flagged(
                id: "asking.patient", group: .asking, title: "Терпеливый", icon: "hourglass",
                done: flags.contains(.patientAnswer),
                caption: L("Дождаться ответа дольше 30 секунд")
            ),
        ]
    }

    private func providers() -> [Achievement] {
        let answered = ProviderCatalog.all
            .compactMap { Self.flag(forProvider: $0.id) }
            .filter(flags.contains)
            .count
        return [
            counted(
                id: "providers.2", group: .providers, title: "Второе мнение",
                icon: "person.2", value: answered, goal: 2,
                caption: L("Получить ответы от двух разных провайдеров")
            ),
            counted(
                id: "providers.all", group: .providers, title: "Полный набор",
                icon: "square.grid.2x2", value: answered, goal: ProviderCatalog.all.count,
                caption: L("Получить ответы от всех провайдеров")
            ),
        ]
    }

    private func mastery(models: ModelManager, history: HistoryStore) -> [Achievement] {
        let defaults = UserDefaults.standard
        let hotkeyChanged = KeyboardShortcuts.Name.toggleRecording.shortcut
            != KeyboardShortcuts.Name.toggleRecording.defaultShortcut
        let styleChanged = AccentStore.shared.hex.uppercased() != "E03E3E"
            || defaults.string(forKey: Prefs.Key.appTheme) != nil
        let downloaded = models.itemStates.values.filter { $0 == .downloaded }.count
        let engines = [Flag.engineWhisperKit, .engineFluidAudio].filter(flags.contains).count

        return [
            flagged(
                id: "mastery.hotkey", group: .mastery, title: "Настроено под себя",
                icon: "command", done: hotkeyChanged, caption: L("Сменить горячую клавишу")
            ),
            flagged(
                id: "mastery.fn", group: .mastery, title: "Один палец", icon: "hand.point.up",
                done: Prefs.toggleRecordingUsesFn, caption: L("Включить запись по клавише fn")
            ),
            flagged(
                id: "mastery.style", group: .mastery, title: "Свой стиль", icon: "paintpalette",
                done: styleChanged, caption: L("Сменить тему или акцентный цвет")
            ),
            flagged(
                id: "mastery.mic", group: .mastery, title: "Свой микрофон", icon: "mic.badge.plus",
                done: defaults.string(forKey: Prefs.Key.inputDeviceUID) != nil,
                caption: L("Выбрать другое устройство ввода")
            ),
            counted(
                id: "mastery.models", group: .mastery, title: "Вторая модель", icon: "square.stack",
                value: downloaded, goal: 2, caption: L("Скачать вторую модель")
            ),
            counted(
                id: "mastery.engines", group: .mastery, title: "Оба движка", icon: "arrow.triangle.swap",
                value: engines, goal: 2, caption: L("Продиктовать через оба движка")
            ),
            flagged(
                id: "mastery.language", group: .mastery, title: "Переключил язык", icon: "globe",
                done: defaults.string(forKey: Prefs.Key.interfaceLanguage) != nil,
                caption: L("Сменить язык интерфейса")
            ),
            flagged(
                id: "mastery.favorite", group: .mastery, title: "Избранное", icon: "star",
                done: flags.contains(.favorite) || history.records.contains(where: \.favorite),
                caption: L("Отметить запись звёздочкой")
            ),
            flagged(
                id: "mastery.playback", group: .mastery, title: "Переслушал", icon: "play.circle",
                done: flags.contains(.playback), caption: L("Воспроизвести запись из истории")
            ),
            flagged(
                id: "mastery.retranscribe", group: .mastery, title: "Второй заход",
                icon: "arrow.clockwise", done: flags.contains(.retranscribe),
                caption: L("Транскрибировать старую запись заново")
            ),
            flagged(
                id: "mastery.onboarding", group: .mastery, title: "Готов к работе",
                icon: "checkmark.seal", done: Prefs.onboardingDone,
                caption: L("Пройти онбординг целиком")
            ),
        ]
    }

    // MARK: - Builders

    /// Measurable achievement: the ring shows "current/goal" while locked.
    private func counted(
        id: String, group: Achievement.Group, title: String, icon: String,
        value: Int, goal: Int, caption: String
    ) -> Achievement {
        let done = value >= goal
        return Achievement(
            id: id, group: group, title: title,
            // A goal of one is a yes/no thing — "400 out of 1" would read as nonsense.
            caption: done
                ? (goal == 1
                    ? L("Выполнено")
                    : L("%@ из %@ — выполнено", Self.grouped(value), Self.grouped(goal)))
                : caption,
            icon: icon,
            fraction: min(1, Double(value) / Double(goal)),
            // Only the current value: 52pt of ring can't hold "10.2k/500k", and the
            // goal is already spelled out in the caption.
            progressLabel: done ? nil : Self.compact(value)
        )
    }

    /// All-or-nothing achievement: no progress to show, the ring keeps a muted icon.
    private func flagged(
        id: String, group: Achievement.Group, title: String, icon: String,
        done: Bool, caption: String
    ) -> Achievement {
        Achievement(
            id: id, group: group, title: title,
            caption: done ? L("Выполнено") : caption,
            icon: icon, fraction: done ? 1 : 0, progressLabel: nil
        )
    }

    // MARK: - Formatting

    /// Space-separated thousands: 1 240. Shared with the metrics card so the
    /// screen never shows the same number in two shapes.
    static func grouped(_ value: Int) -> String {
        StatsFormat.grouped(value)
    }

    /// Short form for the middle of the ring: 1.2k, 340k, 1M.
    static func compact(_ value: Int) -> String {
        value >= 1_000_000 ? "\(value / 1_000_000)M" : StatsFormat.compact(value)
    }

    private static func hours(_ value: Double) -> String {
        value >= 10 ? "\(Int(value))" : String(format: "%.1f", value)
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        do {
            // Decoded through raw strings: a name this build doesn't know about
            // is skipped instead of throwing and losing every earned flag.
            let names = try JSONDecoder().decode([String].self, from: data)
            flags = Set(names.compactMap(Flag.init(rawValue:)))
        } catch {
            log.error("Достижения не прочитаны: \(error)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: HistoryStore.baseFolder, withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(Array(flags))
            try data.write(to: Self.fileURL)
        } catch {
            log.error("Достижения не записаны: \(error)")
        }
    }
}
