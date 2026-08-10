# v0ca.

**Локальная диктовка для macOS.** Нажми комбинацию — говори — текст появляется в активном приложении. Всё распознавание работает на твоём Mac: ни одного байта аудио не покидает устройство.

- ⌥ Space (или просто **fn**) → HUD-капсула записи → текст вставлен
- Локальные ASR-модели: WhisperKit (Whisper / CoreML) и FluidAudio (Parakeet, Neural Engine)
- Каталог из 20+ моделей: от мгновенной Tiny до флагманской Large v3
- Светлая и тёмная темы, 7 акцентных цветов, интерфейс на русском и английском
- История записей с воспроизведением и статистика диктовки
- Push-to-talk, автоперевод речи на английский, кастомные шорткаты

Полностью офлайн. Без подписок и лимитов.

## Первый запуск

Три шага до первой диктовки — разрешения, модель, комбинация:

| | |
|---|---|
| ![Интро](docs/screenshots/onboarding/01-intro.png) | ![Мощно и бесплатно](docs/screenshots/onboarding/02-power-free.png) |
| ![Разрешения](docs/screenshots/onboarding/03-permissions.png) | ![Модель на ваш выбор](docs/screenshots/onboarding/04-model-intro.png) |
| ![Выбор модели](docs/screenshots/onboarding/05-models.png) | ![Кастомные шорткаты](docs/screenshots/onboarding/06-shortcut-intro.png) |
| ![Шорткаты](docs/screenshots/onboarding/07-shortcuts.png) | ![Всё готово](docs/screenshots/onboarding/08-final.png) |

## Сборка

Проект генерируется [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open v0ca.xcodeproj
```

Требуется macOS 14+. Машинно-специфичные настройки подписи — в `Config/Local.xcconfig` (не в гите).

## Документация

- [`docs/PLAN.md`](docs/PLAN.md) — этапы разработки
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — модули и протокол `TranscriptionEngine`
- [`docs/DESIGN.md`](docs/DESIGN.md) — токены дизайн-системы
- [`docs/MODELS.md`](docs/MODELS.md) — каталог моделей
