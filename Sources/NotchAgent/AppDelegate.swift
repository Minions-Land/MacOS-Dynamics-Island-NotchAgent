import AppKit
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindow: NSWindow?
    var statusItem: NSStatusItem?
    var newsManager: NewsManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

        setupStatusBar()

        // Delay window setup slightly to ensure screen geometry is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            setupNotchWindow()
        }

        newsManager = NewsManager()
        Task {
            await newsManager?.fetchInitial()
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage.minionIcon(size: 18)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupNotchWindow() {
        // Find the screen with a notch (safeAreaInsets.top > 0)
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main!

        let screenFrame = screen.frame
        let notchHeight = max(screen.safeAreaInsets.top, 33)
        let notchWidth: CGFloat = 300
        let windowX = screenFrame.midX - notchWidth / 2
        let windowY = screenFrame.maxY - notchHeight

        let contentView = NotchView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSPanel(
            contentRect: NSRect(x: windowX, y: windowY, width: notchWidth, height: notchHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = hostingView
        window.ignoresMouseEvents = false
        window.orderFrontRegardless()

        self.notchWindow = window
    }

    @objc private func refreshNow() {
        Task {
            await newsManager?.refresh()
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
