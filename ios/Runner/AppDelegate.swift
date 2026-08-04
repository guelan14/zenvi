import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    if let envPath = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) {
        do {
            let envContent = try String(contentsOfFile: envPath, encoding: .utf8)
            let lines = envContent.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    if key == "GOOGLE_MAPS_API_KEY" {
                        let apiKey = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                        GMSServices.provideAPIKey(apiKey)
                        break
                    }
                }
            }
        } catch {
            print("Error reading .env")
        }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
