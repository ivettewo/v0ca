import Foundation
import Observation

/// Interface language. Defaults to the system language (Russian system → Russian,
/// English otherwise); the choice made in Settings is saved and overrides the system.
/// Russian is the base language in code (Russian strings serve as keys), translations
/// come from `L10n.en`. Runtime switching without a restart: the class is `@Observable`,
/// so calling `L()` in a View body makes it reactive.
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
            // First launch (no language chosen yet): use the system language —
            // Russian system → Russian UI, anything else → English.
            let system = Locale.preferredLanguages.first ?? "en"
            code = system.hasPrefix("ru") ? .ru : .en
        }
    }
}

/// Localized string. The key is the Russian text. Returned as is for Russian.
@MainActor
func L(_ ru: String) -> String {
    guard AppLanguage.shared.code == .en else { return ru }
    return L10n.en[ru] ?? ru
}

/// English translations. The key is the exact Russian text from the code.
enum L10n {
    static let en: [String: String] = [
        // Sidebar / tabs
        "Настройки": "Settings",
        "Диктовка": "Dictation",
        "Онбординг": "Onboarding",
        "Общие": "General",
        "Модели": "Models",
        "Звук": "Sound",
        "История": "History",
        "Разрешения": "Permissions",

        // Menu bar
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

        // New onboarding (wizard window)
        "Настройка v0ca": "Set up v0ca",
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

        // Onboarding
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

        // General — sections and rows
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

        // Recognition languages
        "Автоопределение": "Auto-detect",
        "Русский": "Russian",
        "Английский": "English",
        "Украинский": "Ukrainian",
        "Немецкий": "German",
        "Французский": "French",
        "Испанский": "Spanish",
        "Португальский": "Portuguese",
        "Итальянский": "Italian",

        // Prefs — insertion method
        "Через буфер (⌘V)": "Via clipboard (⌘V)",
        "Печатать без буфера": "Type without clipboard",
        "Только буфер обмена": "Clipboard only",
        // Clipboard handling
        "Не изменять": "Keep unchanged",
        "Оставлять транскрипт в буфере": "Keep transcript in clipboard",
        // Auto-send
        "Выключено": "Off",
        "Enter после вставки": "Enter after insertion",
        // HUD position
        "Снизу экрана": "Bottom of the screen",
        "Сверху экрана": "Top of the screen",
        // HUD offset
        "Вплотную к краю": "Flush with the edge",
        "Небольшой": "Small",
        "Средний": "Medium",
        "Большой": "Large",
        // Model unloading
        "Никогда": "Never",
        "Через 5 минут": "After 5 minutes",
        "Через 10 минут": "After 10 minutes",
        "Через 15 минут": "After 15 minutes",
        "Через 30 минут": "After 30 minutes",
        "Через 1 час": "After 1 hour",
        "Через 2 часа": "After 2 hours",

        // Models
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

        // Model names from the catalog: qualifiers are Russian in the base data.
        "Whisper Small (компактная)": "Whisper Small (Compact)",
        "Whisper Small (EN, компактная)": "Whisper Small (EN, Compact)",
        "Whisper Large v3 Turbo (компактная)": "Whisper Large v3 Turbo (Compact)",
        "Whisper Large v3 Turbo (мини)": "Whisper Large v3 Turbo (Mini)",
        "Whisper Large v3 (компактная)": "Whisper Large v3 (Compact)",
        "Whisper Large v2 (компактная)": "Whisper Large v2 (Compact)",
        "Distil Large v3 (EN, компактная)": "Distil Large v3 (EN, Compact)",
        "Distil Large v3 Turbo (EN, компактная)": "Distil Large v3 Turbo (EN, Compact)",

        // Models — descriptions from the catalog
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

        // Sound
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

        // History
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
        // History auto-deletion
        "Последние 5": "Last 5",
        "Через 3 дня": "After 3 days",
        "Через 2 недели": "After 2 weeks",
        "Через 3 месяца": "After 3 months",

        // Permissions
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

        // Providers
        "Провайдеры": "Providers",
        "Ключи провайдеров": "Provider keys",
        "Показать остальных провайдеров": "Show other providers",
        "Скрыть остальных провайдеров": "Hide other providers",
        "Подключить": "Connect",
        "Заменить ключ": "Replace key",
        "Удалить ключ «%@»?": "Delete the “%@” key?",
        "Ключ будет удалён из связки ключей. Модели этого провайдера перестанут быть доступны.":
            "The key will be removed from the Keychain. This provider's models will no longer be available.",
        "Какая модель за что отвечает": "Which model does what",
        "Режим «Спросить»": "Ask mode",
        "Текстовый вопрос по вашим заметкам": "A text question about your notes",
        "Режим «Экран»": "Screen mode",
        "Вопрос по снимку экрана — нужна модель со зрением":
            "A question about a screenshot — needs a model with vision",
        "Нет подключённых провайдеров": "No providers connected",
        "Проверяем ключ…": "Checking the key…",
        "Ключ подошёл · %@": "Key works · %@",
        "Ключ не подошёл — провайдер его отклонил": "Key rejected by the provider",
        "Не удалось связаться с провайдером — проверьте соединение":
            "Could not reach the provider — check your connection",
        "Провайдер ответил ошибкой %@": "Provider returned error %@",
        "Непонятный ответ провайдера": "Unexpected response from the provider",
        "Вопросы и снимки экрана уходят провайдеру по API. Локально, на устройстве, работает только транскрибация речи в текст.":
            "Questions and screenshots go to the provider over the API. Only speech-to-text runs locally, on your device.",

        "Режим «%@»": "“%@” mode",
        "Работает, когда включена полоска": "Works when the bar is enabled",

        "Снимок экрана": "Screenshot",
        "Всё": "All",

        // Sound tab
        "Нет доступа к микрофону — включите во вкладке «Разрешения»":
            "No microphone access — enable it on the Permissions tab",
        "Микрофон не найден": "No microphone found",
        "Не удалось запустить: %@": "Could not start: %@",

        // AI achievements
        "Вопросы": "Questions",
        "Снимки экрана": "Screenshots",
        "Как спрашиваешь": "How you ask",
        "Первый вопрос": "First question",
        "Любопытный": "Curious",
        "Собеседник": "Conversationalist",
        "Не отстанет": "Relentless",
        "Задать %@ вопросов голосом": "Ask %@ questions by voice",
        "Первый снимок": "First screenshot",
        "Насмотренный": "Well-watched",
        "Сто экранов": "A hundred screens",
        "Отправить %@ снимков экрана": "Send %@ screenshots",
        "Оба режима": "Both modes",
        "Спросить и голосом, и по экрану": "Ask both by voice and about a screen",
        "Молча": "Wordlessly",
        "Отправить снимок, ничего не сказав": "Send a screenshot without saying anything",
        "Развёрнутый вопрос": "A long question",
        "Задать вопрос длиннее 100 слов": "Ask a question longer than 100 words",
        "Передумал": "Changed your mind",
        "Отменить вопрос во время отсчёта": "Cancel a question during the countdown",
        "Не устроило": "Not good enough",
        "Перегенерировать ответ": "Regenerate an answer",
        "Терпеливый": "Patient",
        "Дождаться ответа дольше 30 секунд": "Wait out an answer longer than 30 seconds",
        "Второе мнение": "A second opinion",
        "Получить ответы от двух разных провайдеров": "Get answers from two different providers",
        "Полный набор": "The full set",
        "Получить ответы от всех провайдеров": "Get answers from every provider",

        // Screen mode
        "Запись экрана": "Screen recording",
        "Снимок экрана для режима «Экран»": "Screenshots for the “Screen” mode",
        "Нужно только для режима «Экран» — без него диктовка работает":
            "Only needed for the “Screen” mode — dictation works without it",
        "Посмотри на снимок экрана. Если на нём есть вопрос или задача — ответь на неё. Если нет — коротко объясни, что здесь происходит и на что стоит обратить внимание.":
            "Look at this screenshot. If it contains a question or a task, answer it. If not, briefly explain what is going on here and what deserves attention.",

        // Ask mode
        "%@ с": "%@ s",
        "Клик — отправить сразу · Esc — отменить": "Click to send now · Esc to cancel",
        "Отправить сразу": "Send now",
        "Перегенерировать": "Regenerate",
        "Закрыть": "Close",
        "Повторить": "Retry",
        "Не выбрана модель — подключите провайдера в настройках":
            "No model selected — connect a provider in Settings",
        "Провайдер отклонил ключ": "The provider rejected the key",
        "Нет связи с провайдером": "Cannot reach the provider",
        "Модель не ответила за %@ секунд": "The model did not answer within %@ seconds",
        "Провайдер не ответил вовремя": "The provider did not answer in time",

        // Always-visible bar
        "Всегда показывать полоску": "Always show the bar",
        "Тонкая полоска у края экрана; наведите на неё — откроется быстрое меню":
            "A thin bar at the screen edge; hover it to open the quick menu",
        "Спросить": "Ask",
        "Экран": "Screen",
        "На устройстве · ничего не покидает Mac": "On device · nothing leaves your Mac",
        "Ваши проиндексированные заметки · ответ от модели по API":
            "Your indexed notes · answered by a model over the API",
        "Весь экран уходит в модель по API": "The whole screen goes to a model over the API",

        // Stats
        "Статистика": "Stats",
        "Завершённых записей": "Completed recordings",
        "Времени речи": "Speech time",
        "Сэкономлено против набора": "Saved versus typing",
        "ч": "h",
        "Слов по дням": "Words per day",
        "Последние %@ дней": "Last %@ days",
        "Появится после первой записи": "Appears after your first recording",
        "Когда вы диктуете": "When you dictate",
        "Пик — %@": "Peak — %@",
        "Пик — нет данных": "Peak — no data",
        "утро": "morning",
        "день": "afternoon",
        "вечер": "evening",
        "ночь": "night",

        // Achievements
        "Достижения · %@ из %@": "Achievements · %@ of %@",
        "%@ из %@": "%@ of %@",
        "%@ из %@ — выполнено": "%@ of %@ — done",
        "%@ ч — выполнено": "%@ h — done",
        "Выполнено": "Done",
        "Объём": "Volume",
        "Диктовки": "Dictations",
        "Серия": "Streak",
        "Рекорды за день": "Daily records",
        "Сэкономленное время": "Time saved",
        "Ритм": "Rhythm",
        "Освоение": "Mastery",
        "Первое слово": "First word",
        "Продиктуйте что-нибудь в первый раз": "Dictate something for the first time",
        "Разговорился": "Warmed up",
        "Десять тысяч": "Ten thousand",
        "Роман": "A novel",
        "Полка": "A shelf",
        "Собрание сочинений": "Collected works",
        "Расшифровать %@ слов": "Transcribe %@ words",
        "Разминка": "Warm-up",
        "Сотня": "A hundred",
        "Пятьсот": "Five hundred",
        "Тысяча": "A thousand",
        "Пять тысяч": "Five thousand",
        "Сделать %@ диктовок": "Make %@ dictations",
        "Три дня": "Three days",
        "Неделя": "A week",
        "Месяц": "A month",
        "Сто дней": "A hundred days",
        "Год": "A year",
        "Диктовать %@ дней подряд": "Dictate %@ days in a row",
        "Продуктивный день": "Productive day",
        "1 000 слов за сутки": "1,000 words in a day",
        "Без остановки": "Non-stop",
        "50 диктовок за сутки": "50 dictations in a day",
        "Монолог": "Monologue",
        "300 слов за одну диктовку": "300 words in one dictation",
        "Длинный монолог": "Long monologue",
        "1 000 слов за одну диктовку": "1,000 words in one dictation",
        "Час свободы": "An hour freed",
        "Сэкономить час против набора": "Save an hour versus typing",
        "Рабочий день": "A working day",
        "Сэкономить рабочий день": "Save a working day",
        "Рабочая неделя": "A working week",
        "Сэкономить рабочую неделю": "Save a working week",
        "Сутки речи": "A day of speech",
        "Наговорить 24 часа": "Speak for 24 hours",
        "Жаворонок": "Early bird",
        "Продиктовать между 05:00 и 08:00": "Dictate between 05:00 and 08:00",
        "Сова": "Night owl",
        "Продиктовать между 00:00 и 04:00": "Dictate between 00:00 and 04:00",
        "Выходной": "Weekend",
        "Продиктовать в субботу или воскресенье": "Dictate on a Saturday or Sunday",
        "Скороговорка": "Tongue twister",
        "Лучший темп — %@ слов в минуту": "Best pace — %@ words per minute",
        "Продиктовать быстрее 150 слов в минуту": "Dictate faster than 150 words per minute",
        "Настроено под себя": "Made your own",
        "Сменить горячую клавишу": "Change the hotkey",
        "Один палец": "One finger",
        "Включить запись по клавише fn": "Turn on recording with the fn key",
        "Свой стиль": "Your own style",
        "Сменить тему или акцентный цвет": "Change the theme or the accent color",
        "Свой микрофон": "Your own microphone",
        "Выбрать другое устройство ввода": "Pick a different input device",
        "Вторая модель": "A second model",
        "Скачать вторую модель": "Download a second model",
        "Оба движка": "Both engines",
        "Продиктовать через оба движка": "Dictate with both engines",
        "Переключил язык": "Language switched",
        "Сменить язык интерфейса": "Change the interface language",
        "Избранное": "Favorites",
        "Отметить запись звёздочкой": "Star a record",
        "Переслушал": "Listened back",
        "Воспроизвести запись из истории": "Play a record from the history",
        "Второй заход": "Second pass",
        "Транскрибировать старую запись заново": "Re-transcribe an old record",
        "Готов к работе": "Ready to work",
        "Пройти онбординг целиком": "Complete the onboarding",
    ]
}

/// Strings with substitution — formatted using the localized template.
@MainActor
func L(_ ru: String, _ argument: CVarArg) -> String {
    String(format: L(ru), argument)
}

@MainActor
func L(_ ru: String, _ first: CVarArg, _ second: CVarArg) -> String {
    String(format: L(ru), first, second)
}
