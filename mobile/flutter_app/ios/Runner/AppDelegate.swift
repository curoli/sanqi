import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var feedbackPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.curoli.sanqi/move_feedback",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      let clip: String
      switch call.method {
      case "move": clip = "move.wav"
      case "gameOver": clip = "game_over.wav"
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let key = FlutterDartProject.lookupKey(forAsset: "assets/sounds/\(clip)")
        guard let url = Bundle.main.url(forResource: key, withExtension: nil) else {
          result(FlutterError(code: "asset", message: "Missing feedback sound.", details: nil))
          return
        }
        try AVAudioSession.sharedInstance().setCategory(.ambient)
        let player = try AVAudioPlayer(contentsOf: url)
        self?.feedbackPlayer?.stop()
        self?.feedbackPlayer = player
        player.play()
        result(nil)
      } catch {
        result(FlutterError(code: "playback", message: error.localizedDescription, details: nil))
      }
    }
  }
}
