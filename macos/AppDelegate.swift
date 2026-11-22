import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private let hosting = NSHostingController(rootView: PopoverView(model: AppModel()))
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.start()
        hosting.rootView = PopoverView(model: model)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "Yoke"
        item.button?.image = icon(filled: false)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 320, height: 520))
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        hosting.view.frame = effect.bounds
        hosting.view.autoresizingMask = [.width, .height]
        effect.addSubview(hosting.view)
        panel.contentView = effect
        self.panel = panel

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.panel?.orderOut(nil)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible, event.window != panel else { return event }
            if let button = self.statusItem?.button, event.window == button.window {
                let point = button.convert(event.locationInWindow, from: nil)
                if button.bounds.contains(point) { return event }
            }
            panel.orderOut(nil)
            return event
        }

        Timer.scheduledTimer(withTimeInterval: 1.0 / 8.0, repeats: true) { [weak self] _ in
            self?.refreshIcon()
        }
        refreshIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }
        place(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func place(_ panel: NSPanel) {
        guard let button = statusItem?.button, let window = button.window else { return }
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = NSScreen.screens.first { $0.frame.intersects(buttonFrame) } ?? window.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let frame = screen?.frame ?? visible
        let menuBar = max(NSStatusBar.system.thickness, frame.maxY - visible.maxY, 54)
        let top = frame.maxY - menuBar - 8
        let width: CGFloat = 320
        let height = min(520, top - visible.minY - 16)
        var x = buttonFrame.midX - width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - width - 8)
        let y = top - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func refreshIcon() {
        statusItem?.button?.image = icon(filled: model.iconFilled)
        statusItem?.button?.toolTip = model.tooltip
    }

    private func icon(filled: Bool) -> NSImage {
        let name = filled ? "gamecontroller.fill" : "gamecontroller"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Yoke") ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

@main
enum YokeMain {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
