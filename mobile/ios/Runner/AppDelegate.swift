import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
  private var oauthEventSink: FlutterEventSink?
  private var pendingOAuthLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterEventChannel(
        name: "eco_nizhny/oauth_links",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setStreamHandler(self)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let link = url.absoluteString
    guard link.hasPrefix("ecodesman://") else {
      return super.application(app, open: url, options: options)
    }

    if let sink = oauthEventSink {
      sink(link)
    } else {
      pendingOAuthLink = link
    }
    return true
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    oauthEventSink = events
    if let link = pendingOAuthLink {
      events(link)
      pendingOAuthLink = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    oauthEventSink = nil
    return nil
  }
}
