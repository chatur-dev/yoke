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
    }

    static func missionControl() {
        notify("com.apple.expose.awake")
    }

    static func appWindows() {
        notify("com.apple.expose.front.awake")
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
