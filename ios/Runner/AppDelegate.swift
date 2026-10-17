import Flutter
import UIKit
import StoreKit

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

        // --- Device Channel (video recordings) ---
        let deviceRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "DevicePlugin")!
        let deviceChannel = FlutterMethodChannel(
            name: "com.topher.zyntune/device",
            binaryMessenger: deviceRegistrar.messenger()
        )
        deviceChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "excludeFromBackup":
                // Videos are large; keep them out of the user's iCloud Backup.
                guard let path = call.arguments as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Expected a file path", details: nil))
                    return
                }
                var url = URL(fileURLWithPath: path)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                do {
                    try url.setResourceValues(values)
                    result(true)
                } catch {
                    result(FlutterError(code: "EXCLUDE_FAILED", message: error.localizedDescription, details: nil))
                }
            case "freeDiskSpace":
                let home = URL(fileURLWithPath: NSHomeDirectory())
                let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                result(values?.volumeAvailableCapacityForImportantUsage.map { NSNumber(value: $0) })
            case "setKeepScreenOn":
                // Video can't record with the screen locked, so keep it awake.
                UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // --- StoreKit Channel ---
        // Asks Apple which build the user first downloaded (for grandfathering)
        // and which purchases are currently active (so lapsed subscriptions end).
        let storeRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "StorePlugin")!
        let storeChannel = FlutterMethodChannel(
            name: "com.topher.zyntune/store",
            binaryMessenger: storeRegistrar.messenger()
        )

        storeChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "originalAppVersion":
                guard #available(iOS 16.0, *) else {
                    result(nil)
                    return
                }
                Task { @MainActor in
                    do {
                        guard case .verified(let transaction) = try await AppTransaction.shared else {
                            result(nil)
                            return
                        }
                        result([
                            "originalAppVersion": transaction.originalAppVersion,
                            "environment": transaction.environment.rawValue,
                        ])
                    } catch {
                        result(FlutterError(code: "APP_TRANSACTION_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            case "activeProductIds":
                Task { @MainActor in
                    var ids: [String] = []
                    for await verification in Transaction.currentEntitlements {
                        if case .verified(let transaction) = verification, transaction.revocationDate == nil {
                            ids.append(transaction.productID)
                        }
                    }
                    result(ids)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
