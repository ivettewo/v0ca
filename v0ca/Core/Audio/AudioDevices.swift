import AVFoundation

struct AudioInputDevice: Identifiable, Hashable {
    let uid: String
    let name: String

    var id: String { uid }
}

/// Список входных аудиоустройств — через AVCaptureDevice, без ручного CoreAudio.
/// Ключ выбранного устройства — `Prefs.Key.inputDeviceUID`.
enum AudioDevices {
    static func inputDevices() -> [AudioInputDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices.map {
            AudioInputDevice(uid: $0.uniqueID, name: $0.localizedName)
        }
    }
}
