import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    appDelegate.fileChannel = FlutterMethodChannel(name: "com.cryptashell/intent", binaryMessenger: flutterViewController.engine.binaryMessenger)

    appDelegate.fileChannel?.setMethodCallHandler({ (call, result) in
        if call.method == "dartIsReady" {
            NSLog("Dart is ready. File in cache: \(appDelegate.pendingFile ?? "None")")

            result(appDelegate.pendingFile)
            appDelegate.pendingFile = nil
        } else {
            result(FlutterMethodNotImplemented)
        }
    })

    super.awakeFromNib()
  }
}