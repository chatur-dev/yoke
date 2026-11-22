import AppKit
import CoreGraphics
import Darwin
import Foundation

enum Spaces {
    static func step(_ direction: Int) {
        guard direction != 0, let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else { return }
        typealias Main = @convention(c) () -> Int32
        typealias Copy = @convention(c) (Int32) -> Unmanaged<CFArray>
        typealias SetSpace = @convention(c) (Int32, CFString, UInt64) -> Void
        guard let mainSym = dlsym(sky, "SLSMainConnectionID"),
              let copySym = dlsym(sky, "SLSCopyManagedDisplaySpaces"),
              let setSym = dlsym(sky, "SLSManagedDisplaySetCurrentSpace") else { return }
        let cid = unsafeBitCast(mainSym, to: Main.self)()
        let displays = unsafeBitCast(copySym, to: Copy.self)(cid).takeRetainedValue() as NSArray
        guard let display = display(underMouse: displays) else { return }
        let spaces = display["Spaces"] as? [NSDictionary] ?? []
        let ids = spaces.compactMap { ($0["id64"] as? NSNumber)?.uint64Value }
        guard let current = (display["Current Space"] as? NSDictionary)?["id64"] as? NSNumber,
              let index = ids.firstIndex(of: current.uint64Value) else { return }
        let next = index + direction
        guard ids.indices.contains(next), let displayID = display["Display Identifier"] as? String else { return }
        unsafeBitCast(setSym, to: SetSpace.self)(cid, displayID as CFString, ids[next])
        hideOverview()
        activateFrontApp()
    }

    static func stepFullscreen(_ direction: Int) {
        step(direction, preferring: 4)
    }

    static func stepDesktop(_ direction: Int) {
        step(direction, preferring: 0)
    }

    private static func step(_ direction: Int, preferring type: Int) {
        guard direction != 0, let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else { return }
        typealias Main = @convention(c) () -> Int32
        typealias Copy = @convention(c) (Int32) -> Unmanaged<CFArray>
        typealias SetSpace = @convention(c) (Int32, CFString, UInt64) -> Void
        guard let mainSym = dlsym(sky, "SLSMainConnectionID"),
              let copySym = dlsym(sky, "SLSCopyManagedDisplaySpaces"),
              let setSym = dlsym(sky, "SLSManagedDisplaySetCurrentSpace") else { return }
        let cid = unsafeBitCast(mainSym, to: Main.self)()
        let displays = unsafeBitCast(copySym, to: Copy.self)(cid).takeRetainedValue() as NSArray
        guard let display = display(underMouse: displays),
              let displayID = display["Display Identifier"] as? String else { return }
        let spaces = display["Spaces"] as? [NSDictionary] ?? []
        guard let current = (display["Current Space"] as? NSDictionary)?["id64"] as? NSNumber,
              let start = spaces.firstIndex(where: { ($0["id64"] as? NSNumber)?.uint64Value == current.uint64Value }),
              spaces.count > 1 else { return }
        let count = spaces.count
        var chosen: UInt64?
        for offset in 1..<count {
            let index = wrap(start + direction * offset, count)
            let space = spaces[index]
            if (space["type"] as? NSNumber)?.intValue == type {
                chosen = (space["id64"] as? NSNumber)?.uint64Value
                break
            }
        }
        if chosen == nil {
            let adjacent = spaces[wrap(start + direction, count)]
            chosen = (adjacent["id64"] as? NSNumber)?.uint64Value
        }
        guard let next = chosen, next != current.uint64Value else { return }
        unsafeBitCast(setSym, to: SetSpace.self)(cid, displayID as CFString, next)
        hideOverview()
        activateFrontApp()
    }

    private static var overviewOpen = false

    private static func hideOverview() {
        guard overviewOpen else { return }
        overviewOpen = false
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true),
           let up = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    static func activateFrontApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { adoptFrontWindow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { adoptFrontWindow() }
    }

    private static func adoptFrontWindow() {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        for window in windows {
            if (window[kCGWindowLayer as String] as? Int ?? 0) != 0 { continue }
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            if owner == "Yoke" || owner == "Dock" || owner == "Window Server" || owner == "Control Center" { continue }
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let app = NSRunningApplication(processIdentifier: pid),
                  app.bundleIdentifier != "dev.chatur.yoke" else { continue }
            if #available(macOS 14, *) {
                _ = app.activate(from: NSRunningApplication.current, options: [])
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            return
        }
    }

    private static func wrap(_ index: Int, _ count: Int) -> Int {
        ((index % count) + count) % count
    }

    private static func notify(_ name: String) {
        guard let dock = dlopen("/System/Library/PrivateFrameworks/DockKit.framework/DockKit", RTLD_LAZY),
              let sym = dlsym(dock, "CoreDockSendNotification") else { return }
        typealias Send = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void
        unsafeBitCast(sym, to: Send.self)(name as CFString, nil)
    }

    private static func display(underMouse displays: NSArray) -> NSDictionary? {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let cg = CGDirectDisplayID(number?.uint32Value ?? 0)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(cg) else {
            return displays.firstObject as? NSDictionary
        }
        let name = CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
        let matched = (displays as? [NSDictionary])?.first { ($0["Display Identifier"] as? String) == name }
        return matched ?? displays.firstObject as? NSDictionary
    }
}
