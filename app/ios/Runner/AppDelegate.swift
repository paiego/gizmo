import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let cheer = FlutterMethodChannel(
      name: "gizmo/cheer",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    cheer.setMethodCallHandler { call, result in
      if call.method == "play" {
        // System sound 1057 is Tink, a short bright confirmation.
        AudioServicesPlaySystemSound(1057)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
