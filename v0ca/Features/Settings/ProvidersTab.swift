import AppKit
import SwiftUI

/// "Providers" tab per the "New screens · Providers" mockup: API keys for the
/// modes that leave the device, and which model handles which mode.
struct ProvidersTab: View {
    let keys: ProviderKeyStore

    @AppStorage(Prefs.Key.askModel) private var askModel: String = ""
    @AppStorage(Prefs.Key.screenModel) private var screenModel: String = ""

    /// The other providers, collapsed by default: OpenAI is the one we expect
    /// people to connect, so it always stays in view.
    @State private var showAll = false
    /// Connected provider whose key is being replaced.
    @State private var editing: String?
    /// Typed-but-not-yet-saved keys, per provider.
    @State private var drafts: [String: String] = [:]
    @FocusState private var focusedField: String?

    /// The provider we lead with — connecting it is the expected path.
    private static let primaryID = "openai"
    /// Field and button share one height so they read as a single control pair.
    private static let controlHeight: CGFloat = 38

    private var connected: [Provider] {
        ProviderCatalog.all.filter { keys.isConnected($0.id) }
    }

    /// Always on top: OpenAI first, then anything else that has a key — a
    /// connected provider must never hide behind a collapsed list.
    private var pinned: [Provider] {
        ProviderCatalog.all.filter { $0.id == Self.primaryID || keys.isConnected($0.id) }
    }

    private var rest: [Provider] {
        ProviderCatalog.all.filter { $0.id != Self.primaryID && !keys.isConnected($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            keysSection
            modelsSection
            privacyNote
        }
    }

    // MARK: - Keys

    private var keysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(L("Ключи провайдеров"))

            ForEach(pinned) { provider in
                if keys.isConnected(provider.id) {
                    connectedCard(provider)
                } else {
                    standaloneConnectCard(provider)
                }
            }

            if !rest.isEmpty {
                disclosure
                if showAll {
                    VStack(spacing: 0) {
                        ForEach(Array(rest.enumerated()), id: \.element.id) { index, provider in
                            if index > 0 {
                                RowDivider()
                            }
                            connectRow(provider)
                        }
                    }
                    .padding(.horizontal, 20)
                    .background(Tokens.surfaceSoft, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    /// Same control as "Show all models" on the Models tab.
    private var disclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { showAll.toggle() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(showAll ? 180 : 0))
                Text(showAll ? L("Скрыть остальных провайдеров") : L("Показать остальных провайдеров"))
                    .font(Tokens.sans(13, weight: .medium))
            }
            .foregroundStyle(Tokens.text2)
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    /// OpenAI before it has a key: the same card as a connected one, but with the
    /// input in place of the mask.
    private func standaloneConnectCard(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(provider.name)
                .font(Tokens.sans(15, weight: .medium))
                .foregroundStyle(Tokens.text)
            keyField(provider)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Tokens.surfaceSoft, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.cardBorder, lineWidth: 1))
    }

    /// A provider with a key: accent border, masked key, replace and delete.
    private func connectedCard(_ provider: Provider) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(provider.name)
                    .font(Tokens.sans(15, weight: .medium))
                    .foregroundStyle(Tokens.text)
                if editing == provider.id {
                    keyField(provider)
                } else {
                    Text(keys.masked(provider.id) ?? "")
                        .font(Tokens.mono(13, weight: .medium))
                        .foregroundStyle(Tokens.textMeta)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if editing != provider.id {
                HStack(spacing: 8) {
                    CircleIconButton(symbol: "arrow.clockwise", help: L("Заменить ключ")) {
                        replace(provider)
                    }
                    CircleIconButton(symbol: "trash", help: L("Удалить"), hoverAccent: true) {
                        confirmAndDelete(provider)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Tokens.surfaceSoft, in: RoundedRectangle(cornerRadius: 16))
        // Same emphasis as the active model card: accent at 1.5pt. Green read as
        // a status badge; this is "the one that is set up", like everywhere else.
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlighted ? Tokens.accent : Tokens.cardBorder,
                        lineWidth: highlighted ? 1.5 : 1)
        )
    }

    /// While the key is being replaced the card is an ordinary editing card —
    /// the accent border would claim it is set up when it is mid-change.
    private var highlighted: Bool {
        editing == nil
    }

    private func replace(_ provider: Provider) {
        drafts[provider.id] = ""
        editing = provider.id
        focusedField = provider.id
    }

    /// Native confirmation, same as deleting a model.
    private func confirmAndDelete(_ provider: Provider) {
        let alert = NSAlert()
        alert.messageText = L("Удалить ключ «%@»?", provider.name)
        alert.informativeText = L(
            "Ключ будет удалён из связки ключей. Модели этого провайдера перестанут быть доступны."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Удалить"))
        alert.addButton(withTitle: L("Отмена"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            keys.remove(provider.id)
        }
    }

    /// A provider without a key: name, field, "Connect".
    private func connectRow(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(provider.name)
                .font(Tokens.sans(15, weight: .medium))
                .foregroundStyle(Tokens.text)
            keyField(provider)
        }
        .padding(.vertical, 16)
    }

    /// Field, button and the line that reports how the check went.
    private func keyField(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            keyInput(provider)
            if let line = statusLine(provider) {
                Text(line.text)
                    .font(Tokens.sans(12))
                    .foregroundStyle(line.color)
                    .padding(.leading, 16)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: keys.status[provider.id])
    }

    private func statusLine(_ provider: Provider) -> (text: String, color: Color)? {
        switch keys.status[provider.id] {
        case .checking:
            (L("Проверяем ключ…"), Tokens.text3)
        case .ok(let count):
            (L("Ключ подошёл · %@", Self.modelsLabel(count)), Tokens.successDeep)
        case .failed(.rejected):
            (L("Ключ не подошёл — провайдер его отклонил"), Tokens.accentHover)
        case .failed(.timedOut):
            (L("Провайдер не ответил вовремя"), Tokens.accentHover)
        case .failed(.unreachable):
            (L("Не удалось связаться с провайдером — проверьте соединение"), Tokens.accentHover)
        case .failed(.http(let code)):
            (L("Провайдер ответил ошибкой %@", "\(code)"), Tokens.accentHover)
        case .failed(.malformed):
            (L("Непонятный ответ провайдера"), Tokens.accentHover)
        case .idle, .none:
            nil
        }
    }

    /// "42 модели" with Russian plural forms.
    private static func modelsLabel(_ count: Int) -> String {
        if AppLanguage.shared.code == .en {
            return count == 1 ? "1 model" : "\(count) models"
        }
        let mod10 = count % 10
        let mod100 = count % 100
        let word: String = if mod10 == 1, mod100 != 11 {
            "модель"
        } else if (2...4).contains(mod10), !(12...14).contains(mod100) {
            "модели"
        } else {
            "моделей"
        }
        return "\(count) \(word)"
    }

    private func keyInput(_ provider: Provider) -> some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: Binding(
                    get: { drafts[provider.id] ?? "" },
                    set: { drafts[provider.id] = $0 }
                ),
                prompt: Text(provider.placeholder)
                    .font(Tokens.mono(13))
                    .foregroundStyle(Tokens.text3)
            )
            .textFieldStyle(.plain)
            .font(Tokens.mono(13, weight: .medium))
            .foregroundStyle(Tokens.text)
            .focused($focusedField, equals: provider.id)
            // Pill, like every other control in the app (dropdowns, the history
            // size field) — the mockup's 10pt corners are a web idiom.
            .padding(.horizontal, 16)
            .frame(height: Self.controlHeight)
            .frame(maxWidth: .infinity)
            .dsFieldStyle(focused: focusedField == provider.id, radius: Self.controlHeight / 2)
            .textCursor()
            .onSubmit { connect(provider) }

            Button {
                connect(provider)
            } label: {
                // Ink-on-paper button from the mockup. The label takes the surface
                // color rather than plain white: in the dark theme the fill flips
                // to near-white and white-on-white would vanish.
                Group {
                    if keys.status[provider.id] == .checking {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                            .colorInvert()
                    } else {
                        Text(L("Подключить"))
                            .font(Tokens.sans(13, weight: .medium))
                            .foregroundStyle(Tokens.surface)
                    }
                }
                .frame(minWidth: 96)
                .padding(.horizontal, 20)
                .frame(height: Self.controlHeight)
                .background(Tokens.text, in: Capsule())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .disabled(keys.status[provider.id] == .checking)
        }
    }

    /// The key is checked against the provider before it is stored, so a green
    /// card always means a key that actually worked at least once.
    private func connect(_ provider: Provider) {
        let key = drafts[provider.id] ?? ""
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        focusedField = nil
        Task {
            await keys.verify(provider, key: key)
            if keys.isConnected(provider.id) {
                drafts[provider.id] = nil
                editing = nil
            }
        }
    }

    // MARK: - Model routing

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(L("Какая модель за что отвечает"))
            VStack(spacing: 0) {
                SettingRow(
                    title: L("Режим «Спросить»"),
                    subtitle: L("Текстовый вопрос по вашим заметкам")
                ) {
                    modelPicker(selection: $askModel, visionOnly: false)
                }
                RowDivider()
                SettingRow(
                    title: L("Режим «Экран»"),
                    subtitle: L("Вопрос по снимку экрана — нужна модель со зрением")
                ) {
                    modelPicker(selection: $screenModel, visionOnly: true)
                }
            }
            .padding(.horizontal, 20)
            .background(Tokens.surfaceSoft, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.radiusCard)
                    .stroke(Tokens.cardBorder, lineWidth: 1)
            )
        }
    }

    /// Only models the connected providers actually reported are offered.
    @ViewBuilder
    private func modelPicker(selection: Binding<String>, visionOnly: Bool) -> some View {
        let options = keys.availableModels(visionOnly: visionOnly)
        if options.isEmpty {
            Text(L("Нет подключённых провайдеров"))
                .font(Tokens.sans(12.5))
                .foregroundStyle(Tokens.text3)
        } else {
            DesignDropdown(
                // Prefixed with the provider so two providers offering a similar
                // model name stay distinguishable.
                options: options.map {
                    (value: "\($0.provider.id)/\($0.model.id)", label: $0.model.name)
                },
                selection: selection,
                width: 240
            )
            .onAppear {
                let values = options.map { "\($0.provider.id)/\($0.model.id)" }
                if !values.contains(selection.wrappedValue) {
                    selection.wrappedValue = values[0]
                }
            }
        }
    }

    private var privacyNote: some View {
        Text(L("Вопросы и снимки экрана уходят провайдеру по API. Локально, на устройстве, работает только транскрибация речи в текст."))
            .font(Tokens.sans(12.5))
            .lineSpacing(3)
            .foregroundStyle(Tokens.accentHover)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Tokens.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Tokens.accentSoftHover, lineWidth: 1)
            )
    }
}
