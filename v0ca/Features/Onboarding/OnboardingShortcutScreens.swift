import KeyboardShortcuts
import SwiftUI

// MARK: - 07B · Кастомные шорткаты

/// Интерстишл перед шагом шорткатов: две большие статичные клавиши ⌥ Space,
/// снизу заголовок. Анимация нажатия из HTML-макета не переносится.
struct OnboardingShortcutIntroScreen: View {
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                OnboardingGradient(HeaderGradient.shortcuts, fade: nil)
                HStack(spacing: 16) {
                    OnboardingKeyCap("⌥", fontSize: 36, animated: true)
                    OnboardingKeyCap("Space", fontSize: 36, animated: true)
                }
                .frame(height: 250)
                .padding(.top, 34)
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(L("Кастомные шорткаты"))
                            .font(Tokens.sans(32, weight: .semibold))
                            .foregroundStyle(Tokens.text)
                        Text(L("Выбирайте и устанавливайте любые клавиши, которые вам необходимы."))
                            .font(Tokens.sans(14))
                            .foregroundStyle(Tokens.text2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 400)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .background(Tokens.surface)
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter(page: 3, back: back) {
                OnboardingPillButton(L("Дальше"), variant: .primary, action: next)
            }
        }
    }
}

// MARK: - 08A/09A · Шорткаты

/// Шаг 3: большие клавиши сверху отражают текущую комбинацию записи и меняются
/// сразу после переназначения (fn → одна клавиша «fn», как в макете 09A).
/// Ниже — рабочие поля: комбинация записи, отмена, тумблер «Нажми и говори».
struct OnboardingShortcutsScreen: View {
    let back: () -> Void
    let next: () -> Void

    @AppStorage(Prefs.Key.pushToTalk) private var pushToTalk = false
    @State private var keys: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                OnboardingGradient(HeaderGradient.shortcuts, height: 260, fade: (from: 0.34, to: 1.0))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        if keys.isEmpty {
                            OnboardingKeyCap("—", fontSize: 24)
                        } else {
                            ForEach(keys, id: \.self) { OnboardingKeyCap($0, fontSize: 24, animated: true) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.18), value: keys)

                    shortcutsCard
                        .padding(.top, 26)

                    Text(L("Шорткаты можно поменять в приложении в любой момент."))
                        .font(Tokens.sans(12))
                        .foregroundStyle(Tokens.text3)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 44)
                .padding(.top, 92)
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter(page: 4, back: back) {
                OnboardingPillButton(L("Завершить"), variant: .primary, action: next)
            }
        }
        .onAppear(perform: refresh)
    }

    private var shortcutsCard: some View {
        VStack(spacing: 0) {
            settingRow(
                title: L("Начать / остановить запись"),
                subtitle: L("Работает поверх любого приложения")
            ) {
                ShortcutField(
                    name: .toggleRecording,
                    fnPrefKey: Prefs.Key.toggleRecordingUsesFn,
                    
                    onChange: refresh
                )
            }
            RowDivider()
            settingRow(
                title: L("Отменить запись"),
                subtitle: L("Сбросить запись, ничего не вставляя")
            ) {
                ShortcutField(name: .cancelRecording)
            }
            RowDivider()
            settingRow(
                title: L("Нажми и говори"),
                subtitle: L("Запись идёт, пока клавиша записи удерживается")
            ) {
                AccentToggle(isOn: $pushToTalk)
            }
        }
        .padding(.horizontal, 20)
        .background(Tokens.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.border, lineWidth: 1))
    }

    private func settingRow(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.sans(14, weight: .medium))
                    .foregroundStyle(Tokens.text)
                Text(subtitle)
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(Tokens.text2)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.vertical, 16)
    }

    private func refresh() {
        let current: [String] = if Prefs.toggleRecordingUsesFn {
            ["fn"]
        } else if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) {
            ShortcutField.keyParts(shortcut)
        } else {
            []
        }
        if current != keys {
            keys = current
        }
    }
}

// MARK: - 10A · Финал

/// «Всё готово»: статичный мокап вставки текста (скелетоны + строка с курсором),
/// по центру футера — «Готово», завершающая онбординг.
struct OnboardingFinalScreen: View {
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                OnboardingGradient(HeaderGradient.final, fade: (from: 0.3, to: 1.0))
                insertionMock
                    .padding(.top, 34)
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(L("Всё готово"))
                            .font(Tokens.sans(32, weight: .semibold))
                            .foregroundStyle(Tokens.text)
                        Text(L("Можно пользоваться: нажмите установленную комбинацию в любом приложении — и начинайте говорить."))
                            .font(Tokens.sans(14))
                            .foregroundStyle(Tokens.text2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 420)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .background(Tokens.surface)
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter {
                OnboardingPillButton(L("Готово"), variant: .primary, action: finish)
            }
        }
    }

    private let animationStart = Date()

    /// Мокап текста в чужом приложении: серые строки-скелетоны, среди них —
    /// только что вставленная фраза (всплывает и растворяется, `vriseIn`)
    /// с мигающим красным курсором (`vblink`, ступенчато).
    private var insertionMock: some View {
        VStack(alignment: .leading, spacing: 11) {
            skeleton(width: 132)
            skeleton(width: 212)
            TimelineView(.animation) { context in
                let time = OnboardingClock.elapsed(context.date, since: animationStart)
                let rise = Self.riseIn(at: time)
                HStack(spacing: 2) {
                    Text(L("Спасибо, записал — присылай детали"))
                        .font(Tokens.sans(15))
                        .foregroundStyle(Tokens.text)
                        .opacity(rise.opacity)
                        .offset(y: rise.offset)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Tokens.accent)
                        .frame(width: 2, height: 18)
                        .opacity(time.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.2)
                }
            }
            .padding(.top, 2)
            skeleton(width: 168)
                .padding(.top, 2)
            skeleton(width: 96)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(width: 360, height: 220, alignment: .top)
        .background(Tokens.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Tokens.hairline, lineWidth: 1))
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: Tokens.surface.opacity(0), location: 0),
                    .init(color: Tokens.surface.opacity(0.9), location: 0.55),
                    .init(color: Tokens.surface, location: 0.92),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 100)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func skeleton(width: CGFloat) -> some View {
        Capsule()
            .fill(Tokens.skeleton)
            .frame(width: width, height: 10)
    }

    /// Керфреймы `vriseIn`: всплытие с +18px к 14%, видна до 88%, растворение.
    private static func riseIn(at time: Double) -> (opacity: Double, offset: Double) {
        let phase = time.truncatingRemainder(dividingBy: 7) / 7
        switch phase {
        case ..<0.14:
            let t = UnitCurve.easeInOut.value(at: phase / 0.14)
            return (t, 18 * (1 - t))
        case ..<0.88:
            return (1, 0)
        default:
            let t = UnitCurve.easeInOut.value(at: (phase - 0.88) / 0.12)
            return (1 - t, 18 * t)
        }
    }
}

// MARK: - Большая клавиша

/// Клавиша-кап из интерстишлов и превью: mono, белый фон, «толстая» нижняя
/// кромка — как `<kbd>` в макете. `animated` — периодическое «нажатие»
/// (керфреймы `vkeyTap`: цикл 2.2s, клавиша утапливается к кромке и отпускается).
struct OnboardingKeyCap: View {
    let symbol: String
    let fontSize: CGFloat
    var animated: Bool = false

    private let start = Date()

    init(_ symbol: String, fontSize: CGFloat, animated: Bool = false) {
        self.symbol = symbol
        self.fontSize = fontSize
        self.animated = animated
    }

    private var radius: CGFloat { fontSize >= 30 ? 16 : 12 }
    private var ledgeOffset: CGFloat { fontSize >= 30 ? 4 : 3 }

    var body: some View {
        if animated {
            TimelineView(.animation) { context in
                key(press: Self.press(at: OnboardingClock.elapsed(context.date, since: start)))
            }
        } else {
            key(press: 0)
        }
    }

    /// `press` 0…1: клавиша съезжает вниз до кромки; кромка остаётся на месте.
    private func key(press: Double) -> some View {
        Text(symbol)
            .font(Tokens.mono(fontSize, weight: .medium))
            .foregroundStyle(Tokens.text)
            .padding(.horizontal, fontSize >= 30 ? 34 : 22)
            .padding(.vertical, fontSize >= 30 ? 22 : 14)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Tokens.border, lineWidth: 1))
            .offset(y: press * ledgeOffset)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Tokens.keycapLedge)
                    .offset(y: ledgeOffset)
            )
    }

    /// Керфреймы `vkeyTap`: нажатие к 10%, держим до 26%, отпускаем к 50%, пауза.
    private static func press(at time: Double) -> Double {
        let phase = time.truncatingRemainder(dividingBy: 2.2) / 2.2
        switch phase {
        case ..<0.10: return UnitCurve.easeInOut.value(at: phase / 0.10)
        case ..<0.26: return 1
        case ..<0.50: return 1 - UnitCurve.easeInOut.value(at: (phase - 0.26) / 0.24)
        default: return 0
        }
    }
}
