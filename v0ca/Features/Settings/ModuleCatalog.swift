import Foundation

/// A piece of a module's page. Modules describe themselves differently — a
/// processing step is a couple of paragraphs, a service needs a list of what it
/// gives and a way to reach its site — so the page is a sequence, not a fixed
/// shape.
enum ModuleBlock {
    case text(String)
    /// Bulleted list: short lines, no trailing punctuation.
    case bullets([String])
    /// A caption and an address; opens in the browser.
    case link(title: String, url: String)
    /// A picture of the setting this module adds elsewhere, drawn with the real
    /// controls but inert. A module that puts a switch on another tab should say
    /// what that switch looks like, so it can be recognized when it appears.
    case settingPreview(where: String, title: String, subtitle: String)
    /// Same idea for a module that adds a whole form rather than a switch: the
    /// card, its field and its button, drawn as they will appear.
    case formPreview(where: String, title: String, placeholder: String, action: String)
}

/// A module as the Modules screen sees it: a name, a line of pitch and a page
/// describing it. Nothing here executes — the switch only writes a flag, and
/// what reads that flag is the feature itself.
struct ModuleInfo: Identifiable {
    let id: String
    let title: String
    /// One line under the title; truncated rather than wrapped, as in the mockup.
    let tagline: String
    let icon: String
    /// The page under the header, top to bottom.
    let body: [ModuleBlock]

    /// Where the switch state lives. **Always off until switched on by hand** —
    /// no module turns itself on, however useful it looks from the inside. A
    /// fresh install is the plain app, and everything beyond it is a decision
    /// someone made on purpose.
    var defaultsKey: String { "module.\(id).enabled" }
}

enum ModuleCatalog {
    static let all: [ModuleInfo] = [polza, screenshot, stats]

    /// Is the module on? Reads `UserDefaults` directly so non-UI code (the
    /// provider catalog, the ask flow) can ask without holding a view's storage.
    static func isEnabled(_ id: String) -> Bool {
        guard let module = all.first(where: { $0.id == id }) else { return false }
        return UserDefaults.standard.bool(forKey: module.defaultsKey)
    }

    // MARK: - Real modules

    private static let polza = ModuleInfo(
        id: "polza",
        title: "Polza AI",
        tagline: "Один ключ к моделям OpenAI, Anthropic, Google и другим",
        icon: "arrow.triangle.branch",
        body: [
            .text("Посредник: один ключ открывает модели OpenAI, Anthropic, Google, xAI и других. Оплата в рублях по договору."),
            .text("Добавляет карточку подключения в «Провайдеры», под кнопкой «Показать остальных провайдеров»:"),
            .formPreview(
                where: "Провайдеры → Ключи провайдеров",
                title: "Polza AI",
                placeholder: "Ключ из личного кабинета polza.ai",
                action: "Подключить"
            ),
            .text("Ключ хранится в связке ключей macOS. После подключения Polza AI появляется в выборе провайдера для режимов «Спросить» и «Экран»."),
            .text("Запрос идёт через серверы Polza AI — на один узел больше, чем при прямом ключе. Распознавание речи остаётся на устройстве."),
            .link(title: "polza.ai", url: "https://polza.ai"),
        ]
    )

    private static let stats = ModuleInfo(
        id: "stats",
        title: "Расширенная статистика",
        tagline: "Длина записей и ещё 19 достижений",
        icon: "chart.bar.xaxis",
        body: [
            .text("Добавляет к обычной статистике разбор по длине записей — от реплик короче 15 секунд до монологов от пяти минут."),
            .bullets([
                "Гистограмма длительностей на вкладке «Статистика»",
                "Группа достижений «Длина»: 10 ступеней от минуты до получаса",
                "Лестница «слов за сутки» продлевается с 1 000 до 25 000",
            ]),
            .text("Счётчики длины ведутся только пока модуль включён. Выключите — записи перестанут в них попадать, но накопленное останется и продолжится с того же места, когда включите обратно."),
            .text("Всё считается на устройстве и никуда не отправляется."),
        ]
    )

    private static let screenshot = ModuleInfo(
        id: "screenshot",
        title: "Оптимизация снимков",
        tagline: "Снимок весит втрое меньше и быстрее уходит провайдеру",
        icon: "arrow.down.right.and.arrow.up.left",
        body: [
            .text("Сжимает снимок экрана перед отправкой в режиме «Экран»."),
            .bullets([
                "Без модуля: 1536 точек по длинной стороне, качество JPEG 0.8",
                "С модулем: 1280 точек, качество от 0.8 вниз, пока файл не станет меньше 300 КБ",
                "Предел — 0.45: ниже модель перестаёт читать мелкий шрифт",
                "Не уложилось на 0.45 — кадр уменьшается до 1024 точек",
            ]),
            .text("На экране 2560×1440 это 250–300 КБ вместо 700–900. Токенов не экономит: провайдер всё равно масштабирует картинку под себя."),
            .text("Переключатель сжатия появляется в «Провайдерах»:"),
            .settingPreview(
                where: "Провайдеры → Какая модель за что отвечает",
                title: "Сжимать снимки экрана",
                subtitle: "Меньше вес — быстрее ответ и дешевле запрос"
            ),
            .text("Обработка идёт в памяти, на диск снимок не попадает."),
        ]
    )
}
