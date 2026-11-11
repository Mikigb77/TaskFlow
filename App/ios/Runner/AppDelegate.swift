import Flutter
import UIKit
import workmanager_apple
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var calendars: DeviceCalendarBridge?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "TaskFlowDeviceCalendars") {
      calendars = DeviceCalendarBridge(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
