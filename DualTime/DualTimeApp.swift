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
    private let clockPopover = NSPopover()
    private var pointerTimer: Timer?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var pointerExitCountdown = PointerExitCountdown()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        clockPopover.delegate = self
        model = AppModel()
        model.start()
        setupStatusItem()
        if !model.hasCompletedOnboarding {
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPopoverMonitoring()
        model.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.font = TimeFormatting.statusBarFont
        button.alignment = .right
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
        statusItem?.length = model.displayWidth
        statusItem?.button?.title = model.displayText
        statusItem?.button?.toolTip = model.timeZone.identifier
    }

    private func updateWindowTitle() {
        settingsWindowController?.window?.title = L10n.string("settings.title", locale: model.locale)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            clockPopover.close()
            let menu = NSMenu()
            let open = NSMenuItem(title: L10n.string("menu.openSettings", locale: model.locale), action: #selector(showSettingsFromMenu), keyEquivalent: "")
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: L10n.string("menu.quit", locale: model.locale), action: #selector(quitFromMenu), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            if clockPopover.isShown {
                clockPopover.close()
            } else {
                let controller = NSHostingController(rootView: ClockListView(model: model))
                clockPopover.contentViewController = controller
                clockPopover.behavior = .applicationDefined
                clockPopover.animates = false
                clockPopover.contentSize = controller.view.fittingSize
                clockPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                startPopoverMonitoring()
            }
        }
    }

    private func pointerIsInsideClock() -> Bool {
        let point = NSEvent.mouseLocation
        if let window = clockPopover.contentViewController?.view.window,
           window.frame.contains(point) { return true }
        if let button = statusItem.button, let window = button.window {
            let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
            if frame.contains(point) { return true }
        }
        return false
    }

    private func startPopoverMonitoring() {
        stopPopoverMonitoring()
        guard clockPopover.isShown else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPointerExit() }
        }
        pointerTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks.union(.keyDown)) { [weak self] event in
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self?.clockPopover.close()
                    return nil
                }
            } else {
                self?.checkOutsideClick()
            }
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            Task { @MainActor in self?.checkOutsideClick() }
        }
    }

    private func checkPointerExit() {
        guard clockPopover.isShown else { return }
        if pointerExitCountdown.shouldClose(
            pointerInside: pointerIsInsideClock(),
            at: ProcessInfo.processInfo.systemUptime,
            delay: model.pointerExitDelay
        ) {
            clockPopover.close()
        }
    }

    private func checkOutsideClick() {
        if clockPopover.isShown, model.closeOnOutsideClick, !pointerIsInsideClock() {
            clockPopover.close()
        }
    }

    private func stopPopoverMonitoring() {
        pointerTimer?.invalidate()
        pointerTimer = nil
        if let monitor = localEventMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalEventMonitor { NSEvent.removeMonitor(monitor) }
        localEventMonitor = nil
        globalEventMonitor = nil
        pointerExitCountdown = PointerExitCountdown()
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
        window.title = L10n.string("settings.title", locale: model.locale)
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 580, height: 600)
        window.setContentSize(NSSize(width: 620, height: 660))
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        settingsWindowController = NSWindowController(window: window)
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        stopPopoverMonitoring()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindowController = nil
    }
}
