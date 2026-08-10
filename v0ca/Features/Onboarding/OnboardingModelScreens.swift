import SwiftUI

// MARK: - 04B · Модель на ваш выбор

/// Интерстишл перед шагом моделей: статичный мокап списка моделей (названия —
/// скелетоны, описания настоящие), снизу заголовок. Анимации макета не переносим.
struct OnboardingModelIntroScreen: View {
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                OnboardingGradient(HeaderGradient.modelIntro, fade: nil)
                modelListMock
                    .padding(.top, 34)
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(L("Модель на ваш выбор"))
                            .font(Tokens.sans(32, weight: .semibold))
                            .foregroundStyle(Tokens.text)
                        VStack(spacing: 0) {
                            Text(L("Выбор из десятка моделей: быстрее, легче, точнее."))
                            Text(L("Меняйте в любой момент."))
                        }
                        .font(Tokens.sans(14))
                        .foregroundStyle(Tokens.text2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .background(Tokens.surface)
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter(page: 2, back: back) {
                OnboardingPillButton(L("Дальше"), variant: .primary, action: next)
            }
        }
    }

    private let animationStart = Date()

    /// Список медленно проскролливается вниз и обратно (керфреймы `vscrollList`
    /// из макета: цикл 14s, ход −190px с паузами на краях).
    private var modelListMock: some View {
        TimelineView(.animation) { context in
            let offset = Self.scrollOffset(at: OnboardingClock.elapsed(context.date, since: animationStart))
            VStack(spacing: 0) {
                mockRow(nameWidth: 104, L("Баланс качества и скорости"), langs: L("100 языков"), size: "466 MB")
                RowDivider()
                mockRow(nameWidth: 132, L("Максимальная точность на длинных записях"), langs: L("100 языков"), size: "1.6 GB")
                RowDivider()
                mockRow(nameWidth: 88, L("Быстрая диктовка только на английском"), langs: L("1 язык"), size: "142 MB")
                RowDivider()
                mockRow(nameWidth: 116, L("Мгновенные заметки на слабом железе"), langs: L("100 языков"), size: "75 MB")
                RowDivider()
                mockRow(nameWidth: 96, L("Шумные записи и несколько говорящих"), langs: L("100 языков"), size: "1.5 GB")
            }
            .offset(y: -offset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(width: 360)
        .background(Tokens.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.hairline, lineWidth: 1))
        .frame(height: 250, alignment: .top)
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: Tokens.surface.opacity(0), location: 0),
                    .init(color: Tokens.surface.opacity(0.9), location: 0.5),
                    .init(color: Tokens.surface, location: 0.92),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 110)
        }
        .clipped()
    }

    /// Керфреймы `vscrollList`: 0–8% стоим, к 54% уезжаем на 190px, до 62% пауза,
    /// к 100% плавно возвращаемся.
    private static func scrollOffset(at time: Double) -> Double {
        let phase = time.truncatingRemainder(dividingBy: 14) / 14
        switch phase {
        case ..<0.08: return 0
        case ..<0.54: return 190 * UnitCurve.easeInOut.value(at: (phase - 0.08) / 0.46)
        case ..<0.62: return 190
        default: return 190 * (1 - UnitCurve.easeInOut.value(at: (phase - 0.62) / 0.38))
        }
    }

    private func mockRow(nameWidth: CGFloat, _ details: String, langs: String, size: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule().fill(Tokens.border).frame(width: nameWidth, height: 11)
            Text(details)
                .font(Tokens.sans(11.5))
                .foregroundStyle(Tokens.text2)
            HStack(spacing: 14) {
                metaLabel("globe", langs, mono: false, size: 11)
                metaLabel("externaldrive", size, mono: true, size: 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
    }
}

/// Иконка + подпись метаданных модели (языки, размер).
private func metaLabel(_ symbol: String, _ text: String, mono: Bool, size: CGFloat = 12) -> some View {
    HStack(spacing: 6) {
        Image(systemName: symbol)
            .font(.system(size: size))
            .opacity(0.75)
        Text(text)
            .font(mono ? Tokens.mono(size, weight: .semibold) : Tokens.sans(size, weight: .semibold))
    }
    .foregroundStyle(Tokens.textMeta)
}

// MARK: - 05A–07A · Модели

/// Шаг 2: реальный каталог. Сверху две рекомендованные модели (Whisper Small
/// и Whisper Large v3 Turbo — компактные варианты), остальные — под разворотом.
/// Загрузка с прогрессом через ModelManager; «Далее» активна, когда на диске
/// есть хотя бы одна модель.
struct OnboardingModelsScreen: View {
    let models: ModelManager
    let back: () -> Void
    let next: () -> Void

    @State private var showAll = false

    /// Верхние карточки: дефолтная компактная Small и компактный турбо-флагман.
    private static let featuredIDs = [
        "openai_whisper-small_216MB",
        "openai_whisper-large-v3-v20240930_626MB",
    ]

    private var featured: [ModelDescriptor] {
        Self.featuredIDs.compactMap { id in models.catalog.first { $0.id == id } }
    }

    private var others: [ModelDescriptor] {
        models.catalog.filter { !Self.featuredIDs.contains($0.id) }
    }

    private var modelReady: Bool {
        models.itemStates.values.contains(.downloaded)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                headerGradient
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L("Модель распознаёт речь прямо на устройстве. Скачайте одну — этого достаточно, чтобы начать."))
                            .font(Tokens.sans(13.5))
                            .foregroundStyle(Tokens.text2)

                        VStack(spacing: 12) {
                            ForEach(featured) { model in
                                featuredCard(model)
                            }
                        }
                        .padding(.top, 18)

                        toggleAllButton
                            .padding(.top, 16)

                        if showAll {
                            othersList
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 44)
                    .padding(.top, 118)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter(page: 3, back: back) {
                HStack(spacing: 16) {
                    if !modelReady {
                        Button(action: next) {
                            Text(L("Скачать позже"))
                                .font(Tokens.sans(12))
                                .foregroundStyle(Tokens.text3)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                        OnboardingDisabledPill(title: L("Далее"))
                    } else {
                        OnboardingPillButton(L("Далее"), variant: .primary, action: next)
                    }
                }
            }
        }
    }

    /// Фон шапки: горизонтальный сине-серый градиент, растворяющийся вниз
    /// (в макете — linear-gradient c mask, не радиальные пятна остальных экранов).
    private var headerGradient: some View {
        LinearGradient(
            colors: [HeaderGradient.modelsLinear.start, HeaderGradient.modelsLinear.end],
            startPoint: .leading, endPoint: .trailing
        )
        .opacity(0.38)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.22),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .frame(height: 220)
        .allowsHitTesting(false)
    }

    // MARK: Карточки

    private func featuredCard(_ model: ModelDescriptor) -> some View {
        let state = models.itemStates[model.id] ?? .notDownloaded
        return VStack(spacing: 0) {
            row(model, state: state, nameSize: 15)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            stripSlot(model, state: state, cornerRadius: 18)
        }
        .background(Tokens.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    state == .downloaded ? Tokens.accent : Tokens.border,
                    lineWidth: state == .downloaded ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    private var othersList: some View {
        VStack(spacing: 0) {
            ForEach(Array(others.enumerated()), id: \.element.id) { index, model in
                let state = models.itemStates[model.id] ?? .notDownloaded
                if index > 0 {
                    RowDivider()
                        .padding(.horizontal, 20)
                }
                row(model, state: state, nameSize: 14)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                stripSlot(model, state: state, cornerRadius: index == others.count - 1 ? 18 : 0)
            }
        }
        .background(Tokens.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.25), value: models.itemStates)
    }

    private func row(_ model: ModelDescriptor, state: ModelManager.ItemState, nameSize: CGFloat) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.name)
                    .font(Tokens.sans(nameSize, weight: .medium))
                    .foregroundStyle(Tokens.text)
                Text(L(model.details))
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(2)
                HStack(spacing: 16) {
                    metaLabel("globe", L(model.languages.label), mono: false)
                    metaLabel("externaldrive", model.sizeLabel, mono: true)
                }
                .padding(.top, 5)
            }
            Spacer(minLength: 0)
            bars(model)
            control(model, state: state)
        }
    }

    /// Полоски «Точность» / «Скорость» (заполнение — из каталога, шкала 1–10).
    private func bars(_ model: ModelDescriptor) -> some View {
        VStack(spacing: 8) {
            bar(L("Точность"), value: model.accuracy)
            bar(L("Скорость"), value: model.speed)
        }
        .frame(width: 140)
    }

    private func bar(_ label: String, value: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Tokens.sans(11))
                .foregroundStyle(Tokens.text3)
                .frame(width: 54, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.surface2)
                    Capsule().fill(Tokens.text)
                        .frame(width: geo.size.width * CGFloat(value) / 10)
                }
            }
            .frame(height: 5)
        }
    }

    @ViewBuilder
    private func control(_ model: ModelDescriptor, state: ModelManager.ItemState) -> some View {
        switch state {
        case .notDownloaded:
            OnboardingDownloadButton { models.download(model.id) }
        case .downloading:
            // В макете тут процент, но по факту нужнее отмена загрузки —
            // прогресс и так виден в красной полосе снизу карточки.
            OnboardingCancelButton { models.cancelDownload(model.id) }
        case .downloaded:
            ZStack {
                Circle().stroke(Tokens.border, lineWidth: 1)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.success)
            }
            .frame(width: 36, height: 36)
        }
    }

    /// Слот полосы прогресса: полоса всегда в лейауте, «выезд» из-под строки и
    /// обратный заезд при отмене — анимация высоты слота (0 ↔ натуральная),
    /// контент прижат к верху и клипится. Никаких transition — реверс симметричен.
    @ViewBuilder
    private func stripSlot(_ model: ModelDescriptor, state: ModelManager.ItemState, cornerRadius: CGFloat) -> some View {
        let percent: Int? = if case .downloading(let p) = state { p } else { nil }
        downloadStrip(model, percent: percent ?? 0, cornerRadius: cornerRadius)
            .frame(height: percent == nil ? 0 : nil, alignment: .top)
            .clipped()
    }

    /// Красная полоса прогресса внизу карточки (макет 06A). Форма задаётся явно:
    /// прямые верхние углы, скругление только снизу (0 — для строк в середине
    /// списка), иначе фон системой рисуется скруглённой «пилюлей» с отступами.
    private func downloadStrip(_ model: ModelDescriptor, percent: Int, cornerRadius: CGFloat) -> some View {
        let doneMB = model.sizeMB * percent / 100
        return HStack(spacing: 14) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.surface.opacity(0.3))
                    Capsule().fill(Tokens.surface)
                        .frame(width: geo.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 6)
            HStack(spacing: 0) {
                Text("\(doneMB)")
                    .font(Tokens.sans(12.5, weight: .semibold))
                    .foregroundStyle(Tokens.textOnAccent)
                Text(" / \(model.sizeLabel)")
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(Tokens.textOnAccent.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius
            )
            .fill(Tokens.accent)
        )
    }

    private var toggleAllButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { showAll.toggle() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(showAll ? 180 : 0))
                Text(showAll ? L("Скрыть остальные модели") : L("Показать все модели"))
                    .font(Tokens.sans(13, weight: .medium))
            }
            .foregroundStyle(Tokens.text2)
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Круглая кнопка отмены загрузки 36×36: крестик в рамке, на ховере краснеет.
private struct OnboardingCancelButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? Tokens.accentHover : Tokens.text2)
                .frame(width: 36, height: 36)
                .background(hovering ? Tokens.accentSoft : Tokens.surface, in: Circle())
                .overlay(Circle().stroke(hovering ? Tokens.accentSoftHover : Tokens.border, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .help(L("Отменить загрузку"))
    }
}

/// Круглая красная кнопка скачивания 36×36.
private struct OnboardingDownloadButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.textOnAccent)
                .frame(width: 36, height: 36)
                .background(hovering ? Tokens.accentHover : Tokens.accent, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
    }
}
