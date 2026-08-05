// Filament Studio — native macOS shell around the single-file HTML app.
// A minimal WKWebView window that loads index.html from disk. localStorage,
// Web Audio, right-click "Inspect Element" all work; window state persists.
//
// Build:
//     swiftc -O AppMain.swift -o "Filament Studio"

import Cocoa
import WebKit

// The HTML file is expected next to the .app bundle (…/Filament Studio.app/../index.html)
// so that live edits to index.html reflect on next launch without re-packaging.
// Falls back to the source tree in ~/TubeLoadLine if not found alongside.
func locateIndexHtml() -> URL {
    let fm = FileManager.default

    // Bundle sibling: /Applications/Filament Studio.app → /Applications/index.html
    // Or ~/Applications/Filament Studio.app → ~/Applications/index.html
    let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
    let sibling = bundleParent.appendingPathComponent("index.html")
    if fm.fileExists(atPath: sibling.path) { return sibling }

    // Bundle Resources/ (if we ever choose to embed a copy):
    if let inside = Bundle.main.url(forResource: "index", withExtension: "html") {
        return inside
    }

    // Dev fallback — the source tree.
    let home = fm.homeDirectoryForCurrentUser
    let src = home.appendingPathComponent("TubeLoadLine/index.html")
    return src
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // WebKit config — enable dev tools + full local file access so any relative asset load works.
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // Default WebsiteDataStore — localStorage persists across launches.

        // Restore last window frame if we've saved one, otherwise centre a sensible default.
        let defaults = UserDefaults.standard
        let savedFrame = defaults.string(forKey: "windowFrame")
        let defaultRect = NSRect(x: 0, y: 0, width: 1440, height: 960)

        window = NSWindow(
            contentRect: defaultRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Filament Studio"
        window.setFrameAutosaveName("MainWindow")
        window.tabbingMode = .disallowed
        if let s = savedFrame {
            window.setFrame(NSRectFromString(s), display: false)
        } else {
            window.center()
        }
        window.minSize = NSSize(width: 900, height: 600)

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        // Match the app's dark aesthetic during page load so we don't flash white.
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.086, alpha: 1.0).cgColor
        window.contentView = webView

        let indexUrl = locateIndexHtml()
        let readRoot = indexUrl.deletingLastPathComponent()
        webView.loadFileURL(indexUrl, allowingReadAccessTo: readRoot)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "windowFrame")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Cmd-R reload — WKWebView's default keybinding doesn't fire for local files, so wire it manually.
    func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Filament Studio", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Filament Studio", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Filament Studio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // View menu with Reload
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Reload", action: #selector(reloadPage), keyEquivalent: "r")
        viewMenu.addItem(withTitle: "Force Reload (ignore cache)", action: #selector(forceReload), keyEquivalent: "R")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Toggle Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func reloadPage() { webView.reload() }
    @objc func forceReload() { webView.reloadFromOrigin() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
delegate.setupMenu()
app.run()
