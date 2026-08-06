// Filament Studio — native macOS shell around the single-file HTML app.
// A minimal WKWebView window that loads index.html from disk. localStorage,
// Web Audio, right-click "Inspect Element" all work; window state persists
// via setFrameAutosaveName.
//
// Build:
//     swiftc -O AppMain.swift -o "Filament Studio"

import Cocoa
import WebKit

// The HTML file is expected next to the .app bundle OR embedded inside
// Contents/Resources/index.html (release builds do the latter).
func locateIndexHtml() -> URL {
    let fm = FileManager.default

    // Bundle sibling: /Applications/Filament Studio.app → /Applications/index.html
    let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
    let sibling = bundleParent.appendingPathComponent("index.html")
    if fm.fileExists(atPath: sibling.path) { return sibling }

    // Embedded in the bundle Resources/ (release builds).
    if let inside = Bundle.main.url(forResource: "index", withExtension: "html") {
        return inside
    }

    // Dev fallback — the source tree.
    let home = fm.homeDirectoryForCurrentUser
    return home.appendingPathComponent("TubeLoadLine/index.html")
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        let config = WKWebViewConfiguration()
        // Older macOS enabled dev tools via KVC; 13.3+ uses WKWebView.isInspectable (below).
        if #unavailable(macOS 13.3) {
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let defaultRect = NSRect(x: 0, y: 0, width: 1440, height: 960)
        window = NSWindow(
            contentRect: defaultRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Filament Studio"
        window.minSize = NSSize(width: 900, height: 600)
        window.setFrameAutosaveName("FilamentStudioMainWindow")
        // If the restored frame isn't fully on any current screen, re-centre.
        if !NSScreen.screens.contains(where: { $0.visibleFrame.contains(window.frame) }) {
            window.center()
        }

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.086, alpha: 1.0)
        }
        window.contentView = webView

        let indexUrl = locateIndexHtml()
        webView.loadFileURL(indexUrl, allowingReadAccessTo: indexUrl.deletingLastPathComponent())

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Menu bar
    func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Filament Studio",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Filament Studio",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Filament Studio",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Reload",
                         action: #selector(reloadPage), keyEquivalent: "r")
        viewMenu.addItem(withTitle: "Force Reload (ignore cache)",
                         action: #selector(forceReload), keyEquivalent: "R")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Toggle Full Screen",
                         action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func reloadPage()  { webView?.reload() }
    @objc func forceReload() { webView?.reloadFromOrigin() }

    // MARK: - JS dialogs
    // WKWebView renders NO UI for alert()/confirm()/prompt() unless the host implements
    // these WKUIDelegate callbacks — without them confirm() silently returns false, which
    // made the Load-amp modal (and every other confirm/prompt in the app) a no-op.

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Filament Studio"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Filament Studio"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Filament Studio"
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn ? field.stringValue : nil)
        }
    }

    // MARK: - Downloads
    // WKWebView ignores <a download> clicks (e.g. the app's "Save .json" export buttons)
    // unless the host app routes them through the WKDownload API (macOS 11.3+). We funnel
    // every download into an NSSavePanel defaulting to ~/Downloads.

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if #available(macOS 11.3, *), navigationAction.shouldPerformDownload {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // A response the view can't render (e.g. a blob served as application/json with a
        // download disposition) becomes a download instead of a dead navigation.
        if #available(macOS 11.3, *), !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

@available(macOS 11.3, *)
extension AppDelegate: WKDownloadDelegate {
    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? panel.url : nil)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        NSLog("FS: download failed: \(error.localizedDescription)")
    }
}

// Bootstrap the app with the classic pattern — this is the most reliable way
// to ensure applicationDidFinishLaunching actually fires from a plain swiftc
// binary (no @main / no NSApplicationMain).
autoreleasepool {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    app.delegate = delegate
    // Retain the delegate strongly for the app's lifetime (NSApplication.delegate is weak).
    objc_setAssociatedObject(app, "kFilamentDelegateRetain",
                             delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
