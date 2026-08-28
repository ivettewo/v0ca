import AVFoundation
import ApplicationServices
import CoreGraphics
import SwiftUI

/// "Permissions" tab: status of Microphone and Accessibility.
struct PermissionsTab: View {
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var axGranted = AXIsProcessTrusted()
    @State private var screenGranted = CGPreflightScreenCaptureAccess()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    static var allGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized && AXIsProcessTrusted()
    }

    var body: some View {
        SettingsSection(title: L("Разрешения")) {
            SettingRow(title: L("Микрофон"), subtitle: micSubtitle) {
                micControl
            }
            RowDivider()
            SettingRow(
                title: L("Универсальный доступ"),
                subtitle: axGranted
                    ? L("Вставка готового текста в активное приложение (⌘V)")
                    : L("Включите v0ca в списке — без этого текст остаётся только в буфере")
            ) {
                axControl
            }
            RowDivider()
            SettingRow(
                title: L("Запись экрана"),
                subtitle: screenGranted
                    ? L("Снимок экрана для режима «Экран»")
                    : L("Нужно только для режима «Экран» — без него диктовка работает")
            ) {
                screenControl
            }
        }

        // Description under the section — from the "Settings · New screens" mockup, 05.
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Оба разрешения обязательны — без них приложение не сможет работать."))
            Text(L("v0ca работает полностью локально. Разрешения нужны только для записи и вставки текста."))
                .frame(maxWidth: 440, alignment: .leading)
        }
        .font(Tokens.sans(12.5))
        .foregroundStyle(Tokens.text3)
        .lineSpacing(4)
        .onReceive(timer) { _ in
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            axGranted = AXIsProcessTrusted()
            screenGranted = CGPreflightScreenCaptureAccess()
        }
    }

    // MARK: - Microphone

    private var micSubtitle: String {
        switch micStatus {
        case .authorized: L("Запись голоса для расшифровки")
        case .denied, .restricted: L("Доступ отклонён — включите v0ca в системных настройках")
        default: L("Запись голоса для расшифровки")
        }
    }

    @ViewBuilder
    private var micControl: some View {
        switch micStatus {
        case .authorized:
            grantedBadge
        case .notDetermined:
            DSButton(L("Разрешить")) {
                Task {
                    _ = await AVCaptureDevice.requestAccess(for: .audio)
                    micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                }
            }
        default:
            // Denied: the system prompt won't show again — Settings is the only way.
            DSButton(L("Открыть настройки")) {
                openSystemSettings("Privacy_Microphone")
            }
        }
    }

    // MARK: - Accessibility

    @ViewBuilder
    private var axControl: some View {
        if axGranted {
            grantedBadge
        } else {
            DSButton(L("Открыть настройки")) {
                let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
                openSystemSettings("Privacy_Accessibility")
            }
        }
    }

    // MARK: - Screen recording

    /// Optional, unlike the other two: only the "Screen" mode needs it, and the
    /// system makes the user restart the app after granting it.
    @ViewBuilder
    private var screenControl: some View {
        if screenGranted {
            grantedBadge
        } else {
            DSButton(L("Разрешить")) {
                CGRequestScreenCaptureAccess()
                openSystemSettings("Privacy_ScreenCapture")
            }
        }
    }

    private var grantedBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Tokens.success)
            Text(L("Разрешено"))
                .font(Tokens.sans(12))
                .foregroundStyle(Tokens.text2)
        }
    }

    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
