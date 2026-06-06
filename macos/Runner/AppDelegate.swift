import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var pendingFile: String?
  var fileChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    NSLog("Finder send URLs: \(urls)")

    // 1. Extraemos el primer archivo que nos mandan
    if let firstUrl = urls.first {
        let filePath = firstUrl.path // Convertimos el objeto URL a la ruta de String que necesita Dart

        if let channel = fileChannel {
            NSLog("🛡️ CRYPTASHELL NATIVO: Motor en vivo. Enviando: \(filePath)")
            channel.invokeMethod("onOpenFile", arguments: filePath)
        } else {
            NSLog("🛡️ CRYPTASHELL NATIVO: App arrancando. Bóveda guardó: \(filePath)")
            pendingFile = filePath
        }
    }

    // 2. CRÍTICO: Dejamos que el motor interno de Flutter procese el evento original
    // por si alguna otra librería depende de ello.
    super.application(application, open: urls)
  }
}