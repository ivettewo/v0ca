import AppKit
import KeyboardShortcuts
import SwiftUI

/// Кастомное поле записи хоткея: клик — режим записи (акцентная пунктирная рамка),
/// нажатое сочетание сохраняется через KeyboardShortcuts, Esc — отмена.
/// Штатный `KeyboardShortcuts.Recorder` в menu-bar-приложении ненадёжно захватывает
/// клавиши, поэтому ловим событие сами локальным монитором (как в mind-wiki).
struct ShortcutField: View {
    let name: KeyboardShortcuts.Name
    /// Ключ UserDefaults «эта комбинация — fn». Если задан, поле умеет ловить fn.
    var fnPrefKey: String?

    @State private var isRecording = false
    @State private var display = ""
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?

    private var usesFn: Bool {
        guard let fnPrefKey else { return false }
        return UserDefaults.standard.bool(forKey: fnPrefKey)
    }

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? L("Нажмите…") : (display.isEmpty ? "—" : display))
                .font(Tokens.mono(13, weight: .medium))
                .foregroundStyle(isRecording ? Tokens.text3 : Tokens.text)
                .lineLimit(1)
                .frame(minWidth: 96)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.radiusControl)
                        .strokeBorder(
                            isRecording ? Tokens.accent : Tokens.border,
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: isRecording ? [4, 3] : []
                            )
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusControl))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onAppear(perform: refresh)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        // Пока записываем — глушим все глобальные хоткеи, иначе нажатие
        // сработает как действие (старт записи), а не запишется в поле.
        KeyboardShortcuts.isEnabled = false
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc — отмена записи
                stopRecording()
                return nil
            }
            if let shortcut = KeyboardShortcuts.Shortcut(event: event) {
                setFn(false)
                KeyboardShortcuts.setShortcut(shortcut, for: name)
                refresh()
                stopRecording()
                return nil
            }
            return event
        }
        // fn не даёт keyDown — ловим отдельным монитором flagsChanged (keyCode 63).
        guard fnPrefKey != nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if event.keyCode == 63, event.modifierFlags.contains(.function) {
                setFn(true)
                KeyboardShortcuts.setShortcut(nil, for: name) // fn заменяет Carbon-хоткей
                refresh()
                stopRecording()
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        keyMonitor = nil
        flagsMonitor = nil
        isRecording = false
        KeyboardShortcuts.isEnabled = true
    }

    private func setFn(_ on: Bool) {
        guard let fnPrefKey else { return }
        UserDefaults.standard.set(on, forKey: fnPrefKey)
    }

    private func refresh() {
        if usesFn {
            display = "fn"
        } else {
            display = KeyboardShortcuts.getShortcut(for: name).map(String.init(describing:)) ?? ""
        }
    }
}

// MARK: - Кнопка (дизайн-система, раздел 06)

/// Варианты кнопок из макета: primary / secondary / ghost / danger-soft / icon.
enum DSButtonVariant {
    case primary, secondary, ghost, dangerSoft, icon
}

/// Кнопка дизайн-системы: высота 36 (compact 28), радиус 8/7, живой hover.
struct DSButton<Label: View>: View {
    var variant: DSButtonVariant = .secondary
    var compact: Bool = false
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var hovering = false

    private var height: CGFloat { variant == .icon ? 36 : (compact ? 28 : 36) }
    private var radius: CGFloat { compact ? 7 : 8 }

    var body: some View {
        Button(action: action) {
            label()
                .font(Tokens.sans(compact ? 12 : 13, weight: .medium))
                .foregroundStyle(foreground)
                .frame(height: height)
                .modifier(WidthModifier(width: variant == .icon ? height : nil,
                                        padding: variant == .icon ? 0 : (compact ? 12 : 18)))
                .background(background, in: RoundedRectangle(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(borderColor, lineWidth: hasBorder ? 1 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: radius))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
    }

    private var hasBorder: Bool { variant == .secondary || variant == .icon }

    private var background: Color {
        switch variant {
        case .primary: hovering ? Tokens.accentHover : Tokens.accent
        case .secondary, .icon: hovering ? Tokens.background : Tokens.surface
        case .ghost: hovering ? Tokens.surface2 : .clear
        case .dangerSoft: hovering ? Tokens.accentSoftHover : Tokens.accentSoft
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: .white
        case .secondary: Tokens.text
        case .icon: hovering ? Tokens.text : Tokens.text2
        case .ghost: hovering ? Tokens.text : Tokens.text2
        case .dangerSoft: Tokens.accentHover
        }
    }

    private var borderColor: Color { hovering ? Tokens.text3.opacity(0.5) : Tokens.border }
}

extension DSButton where Label == Text {
    /// Текстовая кнопка по строке.
    init(_ title: String, variant: DSButtonVariant = .secondary, compact: Bool = false,
         action: @escaping () -> Void) {
        self.init(variant: variant, compact: compact, action: action) { Text(title) }
    }
}

/// Ширина/паддинг: icon-кнопка квадратная, остальные — по горизонтальному паддингу.
private struct WidthModifier: ViewModifier {
    let width: CGFloat?
    let padding: CGFloat
    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width)
        } else {
            content.padding(.horizontal, padding)
        }
    }
}

extension View {
    /// Оформление текстового поля по дизайн-системе: рамка + фокус-ринг
    /// (акцентная рамка `#E03E3E` и розовый ринг `0 0 0 3px #FCEBEB`).
    func dsFieldStyle(focused: Bool, radius: CGFloat = Tokens.radiusControl,
                      fill: Color = Tokens.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(focused ? Tokens.accent : Tokens.border, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(focused ? Tokens.accentSoft : .clear)
                    .padding(-3)
            )
    }

    /// Фон при наведении (для иконок-действий: hover-подсветка по макету).
    func hoverBackground(_ color: Color, radius: CGFloat = 7) -> some View {
        modifier(HoverBackgroundModifier(color: color, radius: radius))
    }

    /// Курсор-указатель (рука) при наведении — для кликабельных контролов.
    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }

    /// То же, но только когда `active == true` (для элементов, кликабельных условно).
    @ViewBuilder
    func pointerCursor(active: Bool) -> some View {
        if active {
            modifier(PointerCursorModifier())
        } else {
            self
        }
    }
}

private struct HoverBackgroundModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(hovering ? color : .clear))
            .onHover { hovering = $0 }
    }
}

/// Пушит/попает `NSCursor.pointingHand` строго парно и чистит стек, если вью
/// исчезает под курсором (иначе курсор «залипает» рукой).
private struct PointerCursorModifier: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    guard !pushed else { return }
                    NSCursor.pointingHand.push()
                    pushed = true
                } else {
                    guard pushed else { return }
                    NSCursor.pop()
                    pushed = false
                }
            }
            .onDisappear {
                if pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
    }
}

/// Секция настроек: заголовок-капс (Label 11/500/+0.1em) + белая карточка со строками.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Tokens.sans(11, weight: .medium))
                .kerning(1.1)
                .foregroundStyle(Tokens.text3)
            VStack(spacing: 0) {
                content
            }
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: Tokens.radiusCard).stroke(Tokens.border, lineWidth: 1))
        }
    }
}

/// Строка настройки: название (+ описание) слева, контрол справа.
struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.sans(13.5))
                    .foregroundStyle(Tokens.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.sans(11.5))
                        .foregroundStyle(Tokens.text3)
                }
            }
            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().overlay(Tokens.border.opacity(0.6)).padding(.leading, 16)
    }
}

/// Тумблер по дизайну: трек 38×22, белая ручка 18px, ход 2→18px, анимация 0.18s.
struct AccentToggle: View {
    @Binding var isOn: Bool
    /// Выключённый тумблер не реагирует на клик и показан приглушённым.
    var enabled: Bool = true

    var body: some View {
        Button {
            guard enabled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? Tokens.accent : Color(hex: 0xD3D3D8))
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .offset(x: isOn ? 18 : 2)
            }
            .opacity(enabled ? 1 : 0.45)
        }
        .pointerCursor(active: enabled)
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
    }
}

/// Переключатель-табы: серый трек, активный сегмент — белая «пилюля» с рамкой.
/// Для выбора из 2–3 равнозначных вариантов, где дропдаун избыточен.
struct DSSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Tokens.surface2, in: RoundedRectangle(cornerRadius: 9))
    }

    private func segment(_ option: (value: Value, label: String)) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = option.value
            }
        } label: {
            Text(option.label)
                .font(Tokens.sans(12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Tokens.text : Tokens.text2)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Tokens.surface)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Tokens.border, lineWidth: 1))
                            .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Дропдаун по дизайн-системе (секция «ДРОПДАУН»): кнопка 36px с фокус-обводкой,
/// раскрытый список — полностью кастомная плавающая панель (NSPanel), без системного
/// оформления/стрелки: розовая подсветка выбранного пункта, красная галочка, hover.
struct DesignDropdown<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var width: CGFloat = 190

    @State private var open = false
    @State private var anchor: NSView?
    @State private var panel = DropdownPanelController()

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 8) {
                Text(currentLabel)
                    .font(Tokens.sans(13))
                    .foregroundStyle(Tokens.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.text3)
            }
            .padding(.horizontal, 12)
            .frame(width: width, height: 36)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.radiusControl)
                    .stroke(open ? Tokens.accent : Tokens.border, lineWidth: 1)
            )
            // Фокус-обводка при открытии: box-shadow 0 0 0 3px #FCEBEB
            .background(
                RoundedRectangle(cornerRadius: Tokens.radiusControl)
                    .fill(open ? Color(hex: 0xFCEBEB) : .clear)
                    .padding(-3)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusControl))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .background(AnchorReader { anchor = $0 })
        .onDisappear { panel.close() }
    }

    private func toggle() {
        if open {
            panel.close()
            return
        }
        guard let rect = anchor?.screenFrame else { return }
        open = true
        panel.onClose = { open = false }
        let list = DropdownList(
            options: options,
            selected: selection,
            width: width
        ) { picked in
            selection = picked
            panel.close()
        }
        panel.show(below: rect, width: width) { AnyView(list) }
    }
}

/// Раскрытый список: карточка радиусом 10 с рамкой и тенью, элементы 32px,
/// выбранный — розовый фон #FCEBEB + текст #C93232 + галочка, остальные — hover.
private struct DropdownList<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    let selected: Value
    let width: CGFloat
    let onPick: (Value) -> Void

    var body: some View {
        VStack(spacing: 1) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selected
                Button {
                    onPick(option.value)
                } label: {
                    HStack(spacing: 8) {
                        Text(option.label)
                            .font(Tokens.sans(13))
                            .foregroundStyle(isSelected ? Tokens.accentHover : Tokens.text)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Tokens.accentHover)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSelected ? Color(hex: 0xFCEBEB) : .clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(5)
        .frame(width: width)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tokens.border, lineWidth: 1))
    }
}

/// Захватывает hosting-NSView, чтобы вычислить экранную позицию для панели списка.
private struct AnchorReader: NSViewRepresentable {
    let onView: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onView(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private extension NSView {
    var screenFrame: NSRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}

/// Плавающая панель списка: borderless NSPanel без системного оформления,
/// закрывается по выбору и по клику мимо.
@MainActor
final class DropdownPanelController {
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    var onClose: (() -> Void)?

    /// Небольшой прозрачный отступ вокруг карточки внутри панели (тени нет).
    private let shadowPad: CGFloat = 4

    func show(below anchor: NSRect, width: CGFloat, content: () -> AnyView) {
        close(fireCallback: false)

        let hosting = NSHostingView(rootView: content().padding(shadowPad))
        hosting.layout()
        let size = hosting.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.contentView = hosting

        // Карточка выровнена под кнопкой: левый край совпадает, верх на 6px ниже.
        let origin = NSPoint(
            x: anchor.minX - shadowPad,
            y: anchor.minY - 6 - (size.height - shadowPad)
        )
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
        self.panel = panel

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window != self?.panel {
                self?.close()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close(fireCallback: Bool = true) {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        if fireCallback { onClose?() }
    }
}
