import AVFoundation

struct AudioInputDevice: Identifiable, Hashable {
    let uid: String
    let name: String

    var id: String { uid }
}

/// List of audio input devices — via AVCaptureDevice, no manual CoreAudio.
/// The selected device is keyed by `Prefs.Key.inputDeviceUID`.
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
