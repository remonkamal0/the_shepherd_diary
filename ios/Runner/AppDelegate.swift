import EventKit
import EventKitUI
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, EKEventEditViewDelegate {
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "ShepherdCalendar") {
      let channel = FlutterMethodChannel(name: "shepherd/calendar", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "addEvent" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let self, let arguments = call.arguments as? [String: Any],
              let start = arguments["start"] as? NSNumber,
              let end = arguments["end"] as? NSNumber else {
          result(FlutterError(code: "calendar", message: "Missing event dates", details: nil))
          return
        }
        self.openCalendar(arguments, start: start, end: end, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func openCalendar(
    _ arguments: [String: Any], start: NSNumber, end: NSNumber, result: @escaping FlutterResult
  ) {
    let present = {
      guard let controller = self.window?.rootViewController,
            controller.presentedViewController == nil else {
        result(FlutterError(code: "calendar", message: "Calendar editor unavailable", details: nil))
        return
      }
      let editor = EKEventEditViewController()
      editor.eventStore = self.eventStore
      editor.editViewDelegate = self
      let event = EKEvent(eventStore: self.eventStore)
      event.title = arguments["title"] as? String
      event.location = arguments["location"] as? String
      event.startDate = Date(timeIntervalSince1970: start.doubleValue / 1000)
      event.endDate = Date(timeIntervalSince1970: end.doubleValue / 1000)
      event.addAlarm(EKAlarm(relativeOffset: -30 * 60))
      editor.event = event
      controller.present(editor, animated: true) { result(nil) }
    }
    if #available(iOS 17.0, *) {
      present()
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async {
          if granted {
            present()
          } else {
            result(FlutterError(code: "calendar", message: "Calendar access denied", details: nil))
          }
        }
      }
    }
  }

  func eventEditViewController(
    _ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction
  ) {
    controller.dismiss(animated: true)
  }
}
