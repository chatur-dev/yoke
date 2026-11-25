import AppKit
import CoreGraphics
import Darwin
import Foundation

/// Full-screen zoom for the display the menu was opened on. SkyLight does not follow the
/// pointer, so while a level is on we pan the viewport when the pointer nears its edge.
final class Magnifier {
    private(set) var factor = 1.0
    private(set) var screenName = ""
    private var displayID: Int32 = 0
    private var center = CGPoint(x: 0, y: 0)
    private var timer: Timer?
    private let sky: UnsafeMutableRawPointer?
    private let connection: Int32
    private let getZoom: GetZoom
    private let setZoom: SetZoom

    private typealias Main = @convention(c) () -> Int32
    private typealias GetZoom = @convention(c) (Int32, Int32, UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Int32
    private typealias SetZoom = @convention(c) (Int32, Int32, UnsafeRawPointer?, Int32, Int32, Double, Double) -> Int32

    init() {
        let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        self.sky = sky
        if let sky,
           let main = dlsym(sky, "SLSMainConnectionID"),
           let getZoom = dlsym(sky, "SLSGetZoomParametersForDisplay"),
           let setZoom = dlsym(sky, "SLSSetZoomParametersForDisplay") {
            connection = unsafeBitCast(main, to: Main.self)()
            self.getZoom = unsafeBitCast(getZoom, to: GetZoom.self)
            self.setZoom = unsafeBitCast(setZoom, to: SetZoom.self)
        } else {
            connection = 0
            getZoom = { _, _, _, _, _ in 1 }
            setZoom = { _, _, _, _, _, _, _ in 1 }
        }
    }

    func set(_ factor: Double, on screen: NSScreen?) -> Bool {
        guard sky != nil, let screen, let id = Self.displayID(screen) else { return false }
        let level = factor <= 1.05 ? 1.0 : min(max(factor, 1.25), 4)
        let frame = Self.quartzFrame(screen)
        let cursor = Self.cursorQuartz()
        if level == 1 {
            apply(id: displayID == 0 ? id : displayID, center: center, factor: 1)
            self.factor = 1
            displayID = 0
            screenName = ""
            timer?.invalidate()
            timer = nil
            return true
        }
        displayID = id
        screenName = screen.localizedName
        self.factor = level
        center = clamped(cursor, in: frame, factor: level)
        apply(id: id, center: center, factor: level)
        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.follow()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        return true
    }

    func off() {
        guard factor > 1 else { return }
        apply(id: displayID, center: center, factor: 1)
        factor = 1
        displayID = 0
        screenName = ""
        timer?.invalidate()
        timer = nil
    }

    private func follow() {
        guard factor > 1, displayID != 0,
              let screen = Self.screen(displayID) else { return }
        let frame = Self.quartzFrame(screen)
        let cursor = Self.cursorQuartz()
        guard frame.insetBy(dx: -80, dy: -80).contains(cursor) else { return }
        let visible = CGSize(width: frame.width / factor, height: frame.height / factor)
        let marginX = max(36, visible.width * 0.14)
        let marginY = max(36, visible.height * 0.14)
        let origin = CGPoint(x: center.x - visible.width / 2, y: center.y - visible.height / 2)
        var next = center
        if cursor.x < origin.x + marginX { next.x -= origin.x + marginX - cursor.x }
        if cursor.x > origin.x + visible.width - marginX { next.x += cursor.x - (origin.x + visible.width - marginX) }
        if cursor.y < origin.y + marginY { next.y -= origin.y + marginY - cursor.y }
        if cursor.y > origin.y + visible.height - marginY { next.y += cursor.y - (origin.y + visible.height - marginY) }
        next = clamped(next, in: frame, factor: factor)
        guard hypot(next.x - center.x, next.y - center.y) > 0.5 else { return }
        center = next
        apply(id: displayID, center: next, factor: factor)
    }

    private func apply(id: Int32, center: CGPoint, factor: Double) {
        var center = center
        _ = withUnsafePointer(to: &center) { setZoom(connection, id, $0, 0, 0, factor, factor) }
    }

    private func clamped(_ point: CGPoint, in frame: CGRect, factor: Double) -> CGPoint {
        let halfW = frame.width / factor / 2
        let halfH = frame.height / factor / 2
        return CGPoint(
            x: min(max(point.x, frame.minX + halfW), frame.maxX - halfW),
            y: min(max(point.y, frame.minY + halfH), frame.maxY - halfH)
        )
    }

    private static func screen(_ id: Int32) -> NSScreen? {
        NSScreen.screens.first { displayID($0) == id }
    }

    private static func displayID(_ screen: NSScreen) -> Int32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.int32Value
    }

    private static func quartzFrame(_ screen: NSScreen) -> CGRect {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        let height = primary?.frame.height ?? 0
        let frame = screen.frame
        return CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
    }

    private static func cursorQuartz() -> CGPoint {
        if let location = CGEvent(source: nil)?.location { return location }
        let cocoa = NSEvent.mouseLocation
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        let height = primary?.frame.height ?? 0
        return CGPoint(x: cocoa.x, y: height - cocoa.y)
    }
}
