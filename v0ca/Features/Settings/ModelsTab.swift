import AppKit
import SwiftUI

/// Каталог моделей — точно по макету «Экран · Настройки», вкладка Models:
/// плоский список, активная карточка залита accentBg, радио-кружок слева,
/// прогрессбары точности/скорости, текстовые кнопки «Удалить»/«Скачать».
struct ModelsTab: View {
    let models: ModelManager

    @State private var searchText = ""
    @State private var languageFilter: LanguageFilter = .all
    @FocusState private var searchFocused: Bool

    enum LanguageFilter: String, CaseIterable {
        case all = "Все языки"
        case multilingual = "Мультиязычные"
        case englishOnly = "Только английский"
    }

    var body: some View {
        HStack(spacing: 10) {
            searchField
            DesignDropdown(
                options: LanguageFilter.allCases.map { (value: $0, label: L($0.rawValue)) },
                selection: $languageFilter,
                width: 180
            )
            openFolderButton
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissFieldFocus)) { _ in
            searchFocused = false
        }

        let downloaded = filtered.filter { models.itemStates[$0.id] == .downloaded }
        let notDownloaded = filtered.filter { models.itemStates[$0.id] != .downloaded }
        // Рекомендованные всплывают отдельной секцией, пока не скачаны; после
        // загрузки они уходят в «Загруженные» и повторно тут не показываются.
        let recommended = notDownloaded.filter(\.recommended)
        let available = notDownloaded.filter { !$0.recommended }

        VStack(alignment: .leading, spacing: 0) {
            if !downloaded.isEmpty {
                section(L("ЗАГРУЖЕННЫЕ"), models: downloaded, downloaded: true, first: true)
            }
            if !recommended.isEmpty {
                section(L("РЕКОМЕНДУЕМ"), models: recommended, downloaded: false, first: downloaded.isEmpty)
            }
            if !available.isEmpty {
                section(
                    L("ДОСТУПНЫ ДЛЯ ЗАГРУЗКИ"),
                    models: available,
                    downloaded: false,
                    first: downloaded.isEmpty && recommended.isEmpty
                )
            }
            if filtered.isEmpty {
                Text(L("Ничего не найдено"))
                    .font(Tokens.sans(12))
                    .foregroundStyle(Tokens.text3)
            }
        }
    }

    /// Секция каталога: капс-заголовок и карточки. `first` убирает верхний отступ
    /// у самой первой секции на экране, какой бы она ни оказалась.
    @ViewBuilder
    private func section(
        _ title: String,
        models list: [ModelDescriptor],
        downloaded: Bool,
        first: Bool
    ) -> some View {
        SectionLabel(title)
            .padding(.top, first ? 0 : 22)
            .padding(.bottom, 8)
        ForEach(Array(list.enumerated()), id: \.element.id) { index, model in
            ModelCard(model: model, models: models, downloaded: downloaded)
                .overlay(alignment: .top) {
                    // Разделители только между карточками, не перед первой.
                    if index > 0, !downloaded {
                        Divider().overlay(Tokens.surface2)
                    }
                }
        }
    }

    private var filtered: [ModelDescriptor] {
        models.catalog.filter { model in
            let matchesSearch = searchText.isEmpty
                || model.name.localizedCaseInsensitiveContains(searchText)
            let matchesLanguage: Bool = switch languageFilter {
            case .all: true
            case .multilingual: model.languages == .multilingual || model.languages == .european
            case .englishOnly: model.languages == .englishOnly
            }
            return matchesSearch && matchesLanguage
        }
    }

    /// Открыть папку с моделями в Finder — оттуда видно все скачанные модели и
    /// можно удалить нужные вручную.
    private var openFolderButton: some View {
        DSButton(variant: .icon) {
            let folder = HFModelDownloader.repoFolder
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        } label: {
            Image(systemName: "folder").font(.system(size: 13))
        }
        .help(L("Открыть папку моделей в Finder"))
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.text3)
            TextField(L("Поиск модели"), text: $searchText)
                .textFieldStyle(.plain)
                .font(Tokens.sans(13))
                .focused($searchFocused)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .dsFieldStyle(focused: searchFocused, fill: searchFocused ? Tokens.surface : Tokens.background)
    }
}

/// Карточка модели по макету. Вся карточка кликабельна — выбирает активную.
private struct ModelCard: View {
    let model: ModelDescriptor
    let models: ModelManager
    let downloaded: Bool

    // Цвета активной карточки из макета
    private static let accentBg = Color(hex: 0xFCEBEB)
    private static let descActive = Color(hex: 0xB96A6A)
    private static let metaActive = Color(hex: 0xC97878)
    private static let strong = Color(hex: 0x4A4A52)
    private static let trackActive = Color(hex: 0xF0C6C6)
    private static let faint = Color(hex: 0xC9C9CF)
    private static let downloadingText = Color(hex: 0xA9722A)

    private var isActive: Bool { models.activeModelID == model.id }

    /// Подпись фазы подготовки активной модели (пока не .ready).
    private var preparingLabel: String {
        switch models.loadState {
        case .downloading(let percent): "\(L("Загрузка")) \(percent)%"
        case .loading: L("Подготовка…")
        case .failed: L("Ошибка")
        case .idle, .ready: L("Подготовка…")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leadingIcon
            content
            bars
            action
        }
        .padding(16)
        .background(
            isActive ? Self.accentBg : .clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if downloaded, !isActive {
                models.setActive(model.id)
            }
        }
        .pointerCursor(active: downloaded && !isActive)
    }

    // MARK: - Левая иконка

    @ViewBuilder
    private var leadingIcon: some View {
        if downloaded {
            DSRadio(selected: isActive)
                .padding(.top, 2)
        } else {
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Self.faint)
                .frame(width: 18, height: 18)
                .padding(.top, 2)
        }
    }

    // MARK: - Текстовая колонка

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(model.name)
                    .font(Tokens.sans(14, weight: .medium))
                    .foregroundStyle(isActive ? Tokens.accentHover : Tokens.text)
                if isActive {
                    if models.loadState == .ready {
                        DSChip(L("Активная"), background: Tokens.surface, foreground: Tokens.accentHover)
                    } else {
                        // Модель выбрана, но ещё грузится/греется — показываем это,
                        // чтобы было понятно, почему первая диктовка ждёт «Подготовку».
                        HStack(spacing: 5) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text(preparingLabel)
                                .font(Tokens.sans(11, weight: .medium))
                                .foregroundStyle(Tokens.accentHover)
                        }
                    }
                }
                if model.recommended {
                    DSChip(
                        L("Рекомендуем"),
                        background: isActive ? Color.white.opacity(0.55) : Tokens.surface2,
                        foreground: isActive ? Tokens.accentHover : Tokens.text2
                    )
                }
                if model.languages == .englishOnly {
                    DSChip(L("Только английский"), background: Tokens.surface2, foreground: Tokens.text2)
                }
            }

            Text(L(model.details))
                .font(Tokens.sans(13))
                .lineSpacing(3)
                .foregroundStyle(isActive ? Self.descActive : Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340, alignment: .leading)

            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .opacity(0.75)
                    Text(L(model.languages.label))
                        .font(Tokens.sans(12, weight: .semibold))
                }
                HStack(spacing: 6) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 11))
                        .opacity(0.75)
                    Text(model.sizeLabel)
                        .font(Tokens.mono(12, weight: .semibold))
                }
            }
            .foregroundStyle(isActive ? Tokens.accentHover : Self.strong)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Прогрессбары точность/скорость

    private var bars: some View {
        VStack(alignment: .leading, spacing: 9) {
            barRow(L("Точность"), value: model.accuracy)
            barRow(L("Скорость"), value: model.speed)
        }
        .frame(width: 140)
        .padding(.top, 2)
    }

    private func barRow(_ label: String, value: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Tokens.sans(11))
                .foregroundStyle(isActive ? Self.metaActive : Tokens.text3)
                .frame(width: 58, alignment: .leading)
            DSProgressBar(
                fraction: CGFloat(value) / 10,
                track: isActive ? Self.trackActive : Tokens.surface2,
                fill: AnyShapeStyle(isActive ? Tokens.accent : Tokens.text)
            )
        }
    }

    // MARK: - Кнопка действия

    @ViewBuilder
    private var action: some View {
        Group {
            if downloaded {
                DSButton(L("Удалить"), variant: .dangerSoft, compact: true) {
                    confirmAndDelete()
                }
            } else if case .downloading(let percent) = models.itemStates[model.id] {
                HStack(spacing: 6) {
                    Text("\(percent)%")
                        .font(Tokens.mono(12, weight: .medium))
                        .foregroundStyle(Self.downloadingText)
                    Button {
                        models.cancelDownload(model.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Tokens.text2)
                            .frame(width: 20, height: 20)
                            .background(Tokens.surface2, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .help(L("Отменить загрузку"))
                }
                .frame(height: 28)
            } else {
                DSButton(L("Скачать"), variant: .secondary, compact: true) {
                    models.download(model.id)
                }
            }
        }
        .frame(width: 82, alignment: .center)
        .padding(.top, 1)
    }

    /// Нативное подтверждение удаления модели (NSAlert) — чтобы случайно не стереть
    /// большую скачанную модель.
    private func confirmAndDelete() {
        let alert = NSAlert()
        alert.messageText = L("Удалить модель «%@»?", model.name)
        alert.informativeText = L(
            "Файлы модели (%@) будут удалены с диска. Скачать заново можно в любой момент.",
            model.sizeLabel
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Удалить"))
        alert.addButton(withTitle: L("Отмена"))
        // Кнопка «Удалить» — деструктивная (красная), где поддерживается.
        if #available(macOS 11.0, *) {
            alert.buttons.first?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertFirstButtonReturn {
            models.delete(model.id)
        }
    }
}
