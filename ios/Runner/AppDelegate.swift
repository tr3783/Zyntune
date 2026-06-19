import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    let metronome = MetronomeEngine()
    var icloudChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // Use separate registrars for each channel to avoid conflicts
        let metronomeRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "MetronomePlugin")!
        let metronomeMessenger = metronomeRegistrar.messenger()

        // --- Metronome Channel ---
        let metronomeChannel = FlutterMethodChannel(
            name: "com.topher.zyntune/metronome",
            binaryMessenger: metronomeMessenger
        )
        MetronomeEngine.channel = metronomeChannel

        metronomeChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "start":
                if let args = call.arguments as? [String: Any] {
                    let bpm = args["bpm"] as? Double ?? 120.0
                    let subdivision = args["subdivision"] as? Int ?? 1
                    self.metronome.start(bpm: bpm, subdivision: subdivision)
                } else {
                    let bpm = (call.arguments as? Double) ?? 120.0
                    self.metronome.start(bpm: bpm, subdivision: 1)
                }
                result(nil)
            case "stop":
                self.metronome.stop()
                result(nil)
            case "updateBpm":
                let bpm = (call.arguments as? Double) ?? 120.0
                self.metronome.updateBpm(bpm)
                result(nil)
            case "updateSubdivision":
                let subdivision = (call.arguments as? Int) ?? 1
                self.metronome.updateSubdivision(subdivision)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // --- iCloud Key-Value Storage Channel ---
        let icloudRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudPlugin")!
        let icloudMessenger = icloudRegistrar.messenger()

        icloudChannel = FlutterMethodChannel(
            name: "com.topher.zyntune/icloud",
            binaryMessenger: icloudMessenger
        )

        icloudChannel?.setMethodCallHandler { call, result in
            do {
                let store = NSUbiquitousKeyValueStore.default
                switch call.method {
                case "setValues":
                    if let args = call.arguments as? [String: Any],
                       let json = args["data"] as? String {
                        store.set(json, forKey: "zyntune_sync_data")
                        let success = store.synchronize()
                        result(success ? nil : FlutterError(code: "SYNC_FAILED", message: "iCloud sync failed", details: nil))
                    } else {
                        result(FlutterError(code: "INVALID_ARGS", message: "Expected data string", details: nil))
                    }
                case "getValues":
                    let json = store.string(forKey: "zyntune_sync_data")
                    result(json)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }
}
