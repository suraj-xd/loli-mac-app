import SwiftUI
import CoreText
import Sparkle

@main
struct LOLIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var notchController: NotchController?
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register bundled fonts (ATSApplicationFontsPath is iOS-only)
        if let fontsURL = Bundle.main.url(forResource: "Fonts", withExtension: nil) {
            if let fontURLs = try? FileManager.default.contentsOfDirectory(
                at: fontsURL, includingPropertiesForKeys: nil
            ) {
                for url in fontURLs where url.pathExtension == "ttf" {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }

        Analytics.setup()
        Analytics.track("appLaunched")

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eyes", accessibilityDescription: "LOLI")
        }
        let menu = NSMenu()
        let checkForUpdates = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        checkForUpdates.target = updaterController
        menu.addItem(checkForUpdates)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit LOLI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu

        notchController = NotchController()
        notchController?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController?.cleanup()
    }
}
