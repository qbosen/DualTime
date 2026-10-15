import AppKit
import Combine
import SwiftUI

@main
struct DualTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var model: AppModel!
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        model.start()
        setupStatusItem()
        if !model.hasCompletedOnboarding {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.font = NSFont.menuBarFont(ofSize: 0)
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
                self?.updateWindowTitle()
            }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []

    private func updateStatusItem() {
        statusItem?.button?.title = model.displayText
        statusItem?.button?.toolTip = model.timeZone.identifier
    }

    private func updateWindowTitle() {
        settingsWindowController?.window?.title = model.language == .chinese ? "DualTime 设置" : "DualTime Settings"
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            showSettings()
            return
        }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            let open = NSMenuItem(title: model.language == .chinese ? "打开设置" : "Open Settings", action: #selector(showSettingsFromMenu), keyEquivalent: "")
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: model.language == .chinese ? "退出" : "Quit", action: #selector(quitFromMenu), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            showSettings()
        }
    }

    @objc private func showSettingsFromMenu() { showSettings() }
    @objc private func quitFromMenu() { NSApplication.shared.terminate(nil) }

    private func showSettings() {
        if let window = settingsWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(model: model)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = model.language == .chinese ? "DualTime 设置" : "DualTime Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 480, height: 400)
        window.setContentSize(NSSize(width: 480, height: 400))
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        settingsWindowController = NSWindowController(window: window)
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindowController = nil
    }
}
