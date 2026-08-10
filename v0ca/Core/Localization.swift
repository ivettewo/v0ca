import Foundation
import Observation

/// Язык интерфейса. По умолчанию — язык системы (русская система → русский,
/// иначе английский); выбор в настройках сохраняется и дальше главнее системы.
/// Русский — базовый в коде (русские строки служат ключами), перевод берётся из
/// `L10n.en`. Рантайм-переключение без перезапуска: класс `@Observable`, поэтому
/// вызов `L()` в теле View делает его реактивным.
@MainActor
@Observable
final class AppLanguage {
    static let shared = AppLanguage()

    enum Code: String, CaseIterable {
        case ru, en
        var label: String { self == .ru ? "Русский" : "English" }
    }

    var code: Code {
        didSet { UserDefaults.standard.set(code.rawValue, forKey: Prefs.Key.interfaceLanguage) }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Prefs.Key.interfaceLanguage),
           let savedCode = Code(rawValue: saved) {
            code = savedCode
        } else {
            // Первый запуск (язык ещё не выбирали): берём язык системы —
            // русская система → русский интерфейс, любая другая → английский.
            let system = Locale.preferredLanguages.first ?? "en"
            code = system.hasPrefix("ru") ? .ru : .en
        }
    }
}

/// Локализованная строка. Ключ — русский текст. Для русского возвращает как есть.
@MainActor
func L(_ ru: String) -> String {
    guard AppLanguage.shared.code == .en else { return ru }
    return L10n.en[ru] ?? ru
}

/// Переводы на английский. Ключ — точный русский текст из кода.
enum L10n {
    static let en: [String: String] = [
        // Сайдбар / вкладки
        "Настройки": "Settings",
        "Диктовка": "Dictation",
        "Онбординг": "Onboarding",
        "Общие": "General",
        "Модели": "Models",
        "Звук": "Sound",
        "История": "History",
        "Разрешения": "Permissions",

        // Меню-бар
        "Начать запись": "Start recording",
        "Остановить запись": "Stop recording",
        "Настройки…": "Settings…",
        "Продолжить настройку…": "Continue setup…",
        "Выйти из v0ca": "Quit v0ca",
        "Загрузка модели…": "Loading model…",

        // HUD
        "Модель…": "Model…",
        "Подготовка…": "Preparing…",
        "Ошибка модели": "Model error",
        "Расшифровка…": "Transcribing…",

        // Новый онбординг (окно-визард)
        "Настройка v0ca": "Set up v0ca",
        "Новый онбординг": "New onboarding",
        "Голос — в текст, в любом приложении. Всё распознаётся локально на вашем устройстве. Три шага — и можно говорить.":
            "Voice to text, in any app. Everything is recognized locally on your device. Three steps — and you're talking.",
        "Начать настройку": "Get started",
        "Мощно и бесплатно": "Powerful and free",
        "Никаких аккаунтов, подписок и лимитов — всё открыто с первого запуска.":
            "No accounts, subscriptions or limits — everything is unlocked from the first launch.",
        "Словарь": "Dictionary",
        "Шорткаты": "Shortcuts",
        "Назад": "Back",
        "Дальше": "Next",
        "Далее": "Next",
        "Настроить позже": "Set up later",
        "Запрос…": "Requesting…",
        "Вставка готового текста в активное приложение":
            "Inserting the finished text into the active app",
        "Оба разрешения обязательны — без них приложение не сможет работать.":
            "Both permissions are required — the app cannot work without them.",
        "Модель на ваш выбор": "A model of your choice",
        "Выбор из десятка моделей: быстрее, легче, точнее.":
            "A dozen models to choose from: faster, lighter, more accurate.",
        "Меняйте в любой момент.": "Switch anytime.",
        "Баланс качества и скорости": "A balance of quality and speed",
        "Максимальная точность на длинных записях": "Maximum accuracy on long recordings",
        "Быстрая диктовка только на английском": "Fast English-only dictation",
        "Мгновенные заметки на слабом железе": "Instant notes on modest hardware",
        "Шумные записи и несколько говорящих": "Noisy recordings and multiple speakers",
        "1 язык": "1 language",
        "Модель распознаёт речь прямо на устройстве. Скачайте одну — этого достаточно, чтобы начать.":
            "The model recognizes speech right on your device. Download one — that's all you need to get started.",
        "Показать все модели": "Show all models",
        "Скрыть остальные модели": "Hide other models",
        "Скачать позже": "Download later",
        "Кастомные шорткаты": "Custom shortcuts",
        "Выбирайте и устанавливайте любые клавиши, которые вам необходимы.":
            "Pick and set any keys you need.",
        "Работает поверх любого приложения": "Works on top of any app",
        "Сбросить запись, ничего не вставляя": "Discard the recording without inserting anything",
        "Запись идёт, пока клавиша записи удерживается": "Records while the recording key is held",
        "Шорткаты можно поменять в приложении в любой момент.":
            "You can change the shortcuts in the app at any time.",
        "Завершить": "Finish",
        "Всё готово": "All set",
        "Нажмите установленную комбинацию и говорите.":
            "Press your shortcut and speak.",
        "Спасибо, записал — присылай детали": "Thanks, noted — send over the details",
        "Готово": "Done",

        // Онбординг
        "Быстрый старт": "Quick start",
        "Выдать разрешения": "Grant permissions",
        "Микрофон — чтобы записывать голос, Универсальный доступ — чтобы вставлять текст":
            "Microphone to record your voice, Accessibility to insert the text",
        "Скачать модель": "Download a model",
        "Подойдёт любая из раздела «Рекомендуем» — дождись конца загрузки":
            "Any model from the Recommended section will do — wait for the download to finish",
        "Назначить комбинацию записи": "Set the recording shortcut",
        "Нажми на поле и зажми сочетание — можно просто fn":
            "Click the field and press a combination — fn alone works",
        "Перейти": "Go",
        "Завершить онбординг": "Finish onboarding",
        "Пропустить": "Skip",
        "Шаги можно пройти в любом порядке — после завершения вкладка исчезнет.":
            "Steps can be done in any order — the tab disappears once you finish.",

        // Общие — секции и строки
        "Запись": "Recording",
        "Нажми и говори": "Push to talk",
        "Запись идёт, пока клавиша удерживается": "Records while the key is held",
        "Язык распознавания": "Recognition language",
        "Переводить речь на английский автоматически": "Translate speech to English automatically",
        "Речь на любом языке распознаётся сразу английским текстом":
            "Speech in any language comes out as English text",
        "Активная модель не умеет переводить — выбери Whisper без пометки Turbo":
            "The active model cannot translate — pick a Whisper model without the Turbo label",
        "Добавлять пробел": "Append a space",
        "Пробел после вставленной транскрибации": "A space after the inserted transcript",
        "Комбинации": "Shortcuts",
        "Начать / остановить запись": "Start / stop recording",
        "Отменить запись": "Cancel recording",
        "Нажмите новую комбинацию…": "Press a new combination…",
        "Вывод": "Output",
        "Метод вставки": "Insertion method",
        "Обработка буфера обмена": "Clipboard handling",
        "Автоматическая отправка": "Auto-send",
        "Система": "System",
        "Язык интерфейса": "Interface language",
        "Запуск при старте системы": "Launch at login",
        "Положение индикатора записи": "Recording indicator position",
        "Отступ от края экрана": "Offset from the screen edge",
        "Выгружать модель": "Unload model",
        "Оформление": "Appearance",
        "Тема": "Theme",
        "Светлая": "Light",
        "Тёмная": "Dark",
        "Системная": "System",
        "Акцентный цвет": "Accent color",
        "Освобождать память, если модель не используется указанное время":
            "Free memory when the model is idle for the set time",

        // Языки распознавания
        "Автоопределение": "Auto-detect",
        "Русский": "Russian",
        "Английский": "English",
        "Украинский": "Ukrainian",
        "Немецкий": "German",
        "Французский": "French",
        "Испанский": "Spanish",
        "Португальский": "Portuguese",
        "Итальянский": "Italian",

        // Prefs — метод вставки
        "Через буфер (⌘V)": "Via clipboard (⌘V)",
        "Печатать без буфера": "Type without clipboard",
        "Только буфер обмена": "Clipboard only",
        // Обработка буфера
        "Не изменять": "Keep unchanged",
        "Оставлять транскрипт в буфере": "Keep transcript in clipboard",
        // Автоотправка
        "Выключено": "Off",
        "Enter после вставки": "Enter after insertion",
        // Положение HUD
        "Снизу экрана": "Bottom of the screen",
        "Сверху экрана": "Top of the screen",
        // Отступ HUD
        "Вплотную к краю": "Flush with the edge",
        "Небольшой": "Small",
        "Средний": "Medium",
        "Большой": "Large",
        // Выгрузка модели
        "Никогда": "Never",
        "Через 5 минут": "After 5 minutes",
        "Через 10 минут": "After 10 minutes",
        "Через 15 минут": "After 15 minutes",
        "Через 30 минут": "After 30 minutes",
        "Через 1 час": "After 1 hour",
        "Через 2 часа": "After 2 hours",

        // Модели
        "Поиск модели": "Search models",
        "Все языки": "All languages",
        "Мультиязычные": "Multilingual",
        "Только английский": "English only",
        "ЗАГРУЖЕННЫЕ": "INSTALLED",
        "РЕКОМЕНДУЕМ": "RECOMMENDED",
        "ДОСТУПНЫ ДЛЯ ЗАГРУЗКИ": "AVAILABLE TO DOWNLOAD",
        "Ничего не найдено": "Nothing found",
        "Активная": "Active",
        "Рекомендуем": "Recommended",
        "Точность": "Accuracy",
        "Скорость": "Speed",
        "Скачать": "Download",
        "Удалить": "Delete",
        "Отмена": "Cancel",
        "Загрузка": "Downloading",
        "Отменить загрузку": "Cancel download",
        "Удалить модель «%@»?": "Delete the model “%@”?",
        "Файлы модели (%@) будут удалены с диска. Скачать заново можно в любой момент.":
            "The model files (%@) will be deleted from disk. You can download it again anytime.",
        "Открыть папку моделей в Finder": "Open the models folder in Finder",
        "100 языков": "100 languages",
        "только английский": "English only",
        "25 языков (вкл. русский)": "25 languages (incl. Russian)",
        "Ошибка": "Error",

        // Модели — описания из каталога
        "Сверхбыстрая расшифровка на 25 европейских языках (вкл. русский). Работает на Neural Engine.":
            "Ultra-fast transcription in 25 European languages (incl. Russian). Runs on the Neural Engine.",
        "Сверхбыстрая английская расшифровка, отличная точность. Работает на Neural Engine.":
            "Ultra-fast English transcription with excellent accuracy. Runs on the Neural Engine.",
        "Мгновенная расшифровка коротких заметок, работает даже на слабом железе.":
            "Instant transcription of short notes, runs even on modest hardware.",
        "Быстрая диктовка с минимальным расходом памяти.":
            "Fast dictation with minimal memory usage.",
        "Баланс качества и скорости для повседневной диктовки: пунктуация, автоопределение языка.":
            "A balance of quality and speed for everyday dictation: punctuation, language auto-detection.",
        "Повседневная диктовка полной точности: пунктуация, автоопределение языка.":
            "Full-precision everyday dictation: punctuation, language auto-detection.",
        "Тяжёлые записи: шум, несколько говорящих, длинные встречи.":
            "Difficult recordings: noise, multiple speakers, long meetings.",
        "Самый компактный турбо-флагман: быстрая диктовка на 100 языках.":
            "The most compact turbo flagship: fast dictation in 100 languages.",
        "Турбо-флагман: лучшее сочетание качества и скорости для диктовки на 100 языках.":
            "Turbo flagship: the best mix of quality and speed for dictation in 100 languages.",
        "Турбо-флагман полной точности: 100 языков, лучший баланс качества и скорости.":
            "Full-precision turbo flagship: 100 languages, the best balance of quality and speed.",
        "Флагманское качество втрое меньшего размера: 100 языков.":
            "Flagship quality at a third of the size: 100 languages.",
        "Максимальное качество: 100 языков, перевод на английский, длинные записи.":
            "Maximum quality: 100 languages, translation to English, long recordings.",
        "Проверенная классика прошлого поколения в компактном виде.":
            "A proven previous-generation classic in a compact form.",
        "Максимальное качество предыдущего поколения, полная точность.":
            "Maximum previous-generation quality, full precision.",
        "Мгновенные заметки на английском.": "Instant notes in English.",
        "Быстрая офлайн-диктовка на английском с минимальным расходом памяти.":
            "Fast offline English dictation with minimal memory usage.",
        "Повседневная диктовка на английском с хорошей пунктуацией.":
            "Everyday English dictation with good punctuation.",
        "Английская диктовка полной точности с хорошей пунктуацией.":
            "Full-precision English dictation with good punctuation.",
        "Тяжёлые английские записи: шум, несколько говорящих, длинные встречи.":
            "Difficult English recordings: noise, multiple speakers, long meetings.",
        "Дистиллированный флагман: качество Large при компактном размере. Только английский.":
            "Distilled flagship: Large-level quality in a compact size. English only.",
        "Дистиллированный флагман полной точности для английского.":
            "Full-precision distilled flagship for English.",
        "Быстрый и компактный: английская диктовка почти без компромиссов.":
            "Fast and compact: English dictation with almost no compromises.",
        "Самый быстрый вариант дистиллированного флагмана для английского.":
            "The fastest variant of the distilled flagship for English.",

        // Звук
        "Выбор микрофона": "Microphone",
        "Устройство": "Device",
        "Системный по умолчанию": "System default",
        "Уровень": "Level",
        "Скажите что-нибудь — индикатор должен двигаться.":
            "Say something — the meter should move.",
        "Проверить": "Check",
        "Стоп": "Stop",
        "Звук начала записи": "Sound when recording starts",
        "Звук завершения": "Sound when finished",
        "Когда текст готов и вставлен": "When the text is ready and inserted",

        // История
        "НАСТРОЙКИ": "SETTINGS",
        "Размер истории": "History size",
        "Автоматическое удаление записей": "Automatic record deletion",
        "Сколько записей хранить — остальные удаляются автоматически":
            "How many records to keep — the rest are deleted automatically",
        "Папка с записями": "Recordings folder",
        "Открыть в Finder": "Open in Finder",
        "ЗАПИСИ": "RECORDS",
        "Сегодня": "Today",
        "Слов расшифровано": "Words transcribed",
        "Подряд": "Day streak",
        "Слов в день в среднем": "Words per day on average",
        "Вчера": "Yesterday",
        "Старые записи удаляются, чтобы не занимать место":
            "Old records are deleted to save space",
        "Открыть": "Open",
        "Воспроизвести": "Play",
        "Записей пока нет — продиктуйте что-нибудь.": "No records yet — dictate something.",
        "Скопировать": "Copy",
        "В избранное": "Favorite",
        "Транскрибировать заново": "Re-transcribe",
        // Автоудаление истории
        "Последние 5": "Last 5",
        "Через 3 дня": "After 3 days",
        "Через 2 недели": "After 2 weeks",
        "Через 3 месяца": "After 3 months",

        // Разрешения
        "Микрофон": "Microphone",
        "Универсальный доступ": "Accessibility",
        "Запись голоса для расшифровки": "Voice recording for transcription",
        "Доступ отклонён — включите v0ca в системных настройках":
            "Access denied — enable v0ca in System Settings",
        "Вставка готового текста в активное приложение (⌘V)":
            "Inserting the finished text into the active app (⌘V)",
        "Включите v0ca в списке — без этого текст остаётся только в буфере":
            "Enable v0ca in the list — otherwise the text stays in the clipboard only",
        "v0ca работает полностью локально. Разрешения нужны только для записи и вставки текста.":
            "v0ca runs fully locally. Permissions are only needed to record and insert text.",
        "Разрешено": "Granted",
        "Разрешить": "Allow",
        "Открыть настройки": "Open Settings",
    ]
}

/// Строки с подстановкой — форматируем по локализованному шаблону.
@MainActor
func L(_ ru: String, _ argument: CVarArg) -> String {
    String(format: L(ru), argument)
}
