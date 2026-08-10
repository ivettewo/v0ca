import AppKit
import SwiftUI

/// Model catalog per the "Settings · New screens" mockup, tab 02:
/// pinned header (search + language filter + folder button), downloaded and
/// recommended models as cards on top, the rest under an expandable list.
/// No more chips or text buttons: download/delete/cancel are round icons.
struct ModelsTab: View {
    let models: ModelManager

    @State private var searchText = ""
    @State private var languageFilter: LanguageFilter = .all
    @State private var showAll = false
    @FocusState private var searchFocused: Bool

    enum LanguageFilter: String, CaseIterable {
        case all = "Все языки"
        case multilingual = "Мультиязычные"
        case englishOnly = "Только английский"
    }


    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
            Section {
                catalog
            } header: {
                headerBar
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissFieldFocus)) { _ in
            searchFocused = false
        }
    }

    // MARK: - Pinned header

    /// Sticks to the top while scrolling; the white backdrop extends into the
    /// panel padding so cards don't show through under the controls.
    private var headerBar: some View {
        HStack(spacing: 10) {
            searchField
            DesignDropdown(
                options: LanguageFilter.allCases.map { (value: $0, label: L($0.rawValue)) },
                selection: $languageFilter,
                width: 180
            )
            folderButton
        }
        .padding(.bottom, 12)
        .background(
            Tokens.surface
                .padding(.horizontal, -24)
                .padding(.top, -24)
        )
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.text3)
            TextField(L("Поиск модели"), text: $searchText)
                .textFieldStyle(.plain)
                .font(Tokens.sans(13))
                .focused($searchFocused)
        }
        .padding(.leading, 13)
        .padding(.trailing, 14)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(Tokens.surface, in: Capsule())
        .overlay(
            Capsule().stroke(searchFocused ? Tokens.accent : Tokens.controlBorder, lineWidth: 1)
        )
        // Focus ring like the design-system fields.
        .background(Capsule().fill(searchFocused ? Tokens.accentSoft : .clear).padding(-3))
        .textCursor()
        .unfocusOnOutsideClick($searchFocused)
    }

    /// Open the models folder in Finder — it shows all downloaded models and
    /// lets you delete them manually. The mockup has no icon — we draw one in a circle.
    private var folderButton: some View {
        CircleIconButton(symbol: "folder", help: L("Открыть папку моделей в Finder")) {
            let folder = HFModelDownloader.repoFolder
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }

    // MARK: - Catalog

    /// With search or filter active, the whole list is expanded and the collapse toggle is inert.
    private var filterActive: Bool {
        !searchText.isEmpty || languageFilter != .all
    }

    private func isDownloaded(_ model: ModelDescriptor) -> Bool {
        models.itemStates[model.id] == .downloaded
    }

    @ViewBuilder
    private var catalog: some View {
        let downloaded = filtered.filter { isDownloaded($0) }
        let recommended = filtered.filter { $0.recommended && !isDownloaded($0) }
        let rest = filtered.filter { !$0.recommended && !isDownloaded($0) }

        if filtered.isEmpty {
            Text(L("Ничего не найдено"))
                .font(Tokens.sans(12))
                .foregroundStyle(Tokens.text3)
        } else {
            VStack(spacing: 12) {
                ForEach(downloaded + recommended) { model in
                    card(model)
                }
            }

            if !rest.isEmpty {
                if !filterActive {
                    toggleAllButton
                }
                if showAll || filterActive {
                    restList(rest)
                }
            }
        }
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

    private var filtered: [ModelDescriptor] {
        models.catalog.filter { model in
            let matchesSearch = searchText.isEmpty
                || model.name.localizedCaseInsensitiveContains(searchText)
                || L(model.name).localizedCaseInsensitiveContains(searchText)
            let matchesLanguage: Bool = switch languageFilter {
            case .all: true
            case .multilingual: model.languages == .multilingual || model.languages == .european
            case .englishOnly: model.languages == .englishOnly
            }
            return matchesSearch && matchesLanguage
        }
    }

    // MARK: - Cards

    /// Standalone card (downloaded and recommended models). The active one gets
    /// a 1.5pt accent border; clicking a downloaded card makes it active.
    private func card(_ model: ModelDescriptor) -> some View {
        let state = models.itemStates[model.id] ?? .notDownloaded
        let isActive = models.activeModelID == model.id && state == .downloaded
        return VStack(spacing: 0) {
            row(model, state: state, nameSize: 15)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            downloadStripSlot(model, state: state, cornerRadius: 18)
        }
        .background(Tokens.surfaceSoft, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isActive ? Tokens.accent : Tokens.cardBorder, lineWidth: isActive ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.25), value: state)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            if state == .downloaded, !isActive {
                models.setActive(model.id)
            }
        }
        .pointerCursor(active: state == .downloaded && !isActive)
    }

    /// Collapsed list of the "rest": a single container, rows separated by dividers.
    private func restList(_ list: [ModelDescriptor]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, model in
                let state = models.itemStates[model.id] ?? .notDownloaded
                if index > 0 {
                    RowDivider()
                        .padding(.horizontal, 20)
                }
                row(model, state: state, nameSize: 14)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                downloadStripSlot(model, state: state, cornerRadius: index == list.count - 1 ? 18 : 0)
            }
        }
        .background(Tokens.surfaceSoft, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.25), value: models.itemStates)
    }

    private func row(_ model: ModelDescriptor, state: ModelManager.ItemState, nameSize: CGFloat) -> some View {
        let isActive = models.activeModelID == model.id && state == .downloaded
        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(L(model.name))
                        .font(Tokens.sans(nameSize, weight: .medium))
                        .foregroundStyle(Tokens.text)
                    if isActive, models.loadState != .ready {
                        preparingIndicator
                    }
                }
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

    /// Model is selected but still downloading/warming up — why the first dictation waits.
    private var preparingIndicator: some View {
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

    private var preparingLabel: String {
        switch models.loadState {
        case .downloading(let percent): "\(L("Загрузка")) \(percent)%"
        case .failed: L("Ошибка")
        case .idle, .loading, .ready: L("Подготовка…")
        }
    }

    private func metaLabel(_ symbol: String, _ text: String, mono: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .opacity(0.75)
            Text(text)
                .font(mono ? Tokens.mono(12, weight: .semibold) : Tokens.sans(12, weight: .semibold))
        }
        .foregroundStyle(Tokens.textMeta)
    }

    /// "Accuracy" / "Speed" bars (catalog scale 1–10).
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

    // MARK: - Actions

    @ViewBuilder
    private func control(_ model: ModelDescriptor, state: ModelManager.ItemState) -> some View {
        switch state {
        case .downloaded:
            CircleIconButton(
                symbol: "trash",
                help: L("Удалить"),
                hoverAccent: true
            ) {
                confirmAndDelete(model)
            }
        case .downloading:
            CircleIconButton(symbol: "xmark", help: L("Отменить загрузку")) {
                models.cancelDownload(model.id)
            }
        case .notDownloaded:
            DownloadCircleButton { models.download(model.id) }
        }
    }

    /// Slot for the red progress strip under a row: height animates 0 ↔ full,
    /// appearance and hiding are symmetric (pattern from the onboarding models screen).
    @ViewBuilder
    private func downloadStripSlot(_ model: ModelDescriptor, state: ModelManager.ItemState, cornerRadius: CGFloat) -> some View {
        let percent: Int? = if case .downloading(let p) = state { p } else { nil }
        downloadStrip(model, percent: percent ?? 0, cornerRadius: cornerRadius)
            .frame(height: percent == nil ? 0 : nil, alignment: .top)
            .clipped()
    }

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

    /// Native model deletion confirmation (NSAlert) — so a large downloaded
    /// model isn't wiped by accident.
    private func confirmAndDelete(_ model: ModelDescriptor) {
        let alert = NSAlert()
        alert.messageText = L("Удалить модель «%@»?", L(model.name))
        alert.informativeText = L(
            "Файлы модели (%@) будут удалены с диска. Скачать заново можно в любой момент.",
            model.sizeLabel
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Удалить"))
        alert.addButton(withTitle: L("Отмена"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            models.delete(model.id)
        }
    }
}

// MARK: - Round buttons

/// Round 36×36 icon button with a border; `hoverAccent` turns it pink
/// and red on hover (the trash button from the mockup).
private struct CircleIconButton: View {
    let symbol: String
    let help: String
    var hoverAccent: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering && hoverAccent ? Tokens.accentHover : Tokens.text2)
                .frame(width: 36, height: 36)
                .background(
                    hovering ? (hoverAccent ? Tokens.accentSoft : Tokens.background) : Tokens.surface,
                    in: Circle()
                )
                .overlay(
                    Circle().stroke(
                        hovering && hoverAccent ? Tokens.accentSoftHover : Tokens.controlBorder,
                        lineWidth: 1
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// Round red 36×36 download button.
private struct DownloadCircleButton: View {
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
        .help(L("Скачать"))
    }
}
