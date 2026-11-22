import AppKit
import CoreGraphics
import Foundation

/// Posts pointer, scroll, and key events. Synthetic Fn is unreliable; Right Option is the dictation default because Wispr accepts a modifier on its own and macOS will actually deliver it.
final class EventInjector {
    private let source: CGEventSource?
    private var residualMouse = CGPoint.zero
    private var residualScroll = CGPoint.zero
    private var clicks: Set<MouseButton> = []
    private var heldKeys: Set<KeyCombo> = []
    private var modifierFlags: CGEventFlags = []
    private var modifierKeyCode: CGKeyCode = 61
    private var functionDown = false
    private var functionAsserted = Date.distantPast
    private var modifierKeysDown: Set<CGKeyCode> = []
    private var keyRepeatAt: [KeyCombo: Date] = [:]
    private var cursorQuartz: CGPoint?
    private var pressOrigin: CGPoint?
    private var draggedPastSlop = false
    private let clickSlop: CGFloat = 8

    init() {
        source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        // A previous command key event can stay latched in the shared HID source.
        // Command-click on a Dock icon reveals the app in Finder instead of activating it.
        postFlags([], keyCode: 55)
    }

    func apply(_ frame: FrameOutput) {
        if clicks.isEmpty, !frame.clicks.isEmpty {
            setClicks(frame.clicks)
        }
        move(dx: frame.mouseX, dy: frame.mouseY)
        scroll(dx: frame.scrollX, dy: frame.scrollY)
        if frame.deleteCount > 0, let chunk = frame.deleteChunk {
            for _ in 0..<frame.deleteCount { postDelete(chunk) }
        }
        setClicks(frame.clicks)
        setHeldKeys(frame.heldKeys)
        for combo in frame.tappedKeys {
            tap(combo)
        }
        repeatHeldKeys()
        if frame.focusText { Focus.frontmostText() }
    }

    func releaseAll() {
        setClicks([])
        setHeldKeys([])
        residualMouse = .zero
        residualScroll = .zero
    }

    private func move(dx: Double, dy: Double) {
        residualMouse.x += dx
        residualMouse.y += dy
        let stepX = residualMouse.x.rounded(.towardZero)
        let stepY = residualMouse.y.rounded(.towardZero)
        guard stepX != 0 || stepY != 0 else { return }
        if !clicks.isEmpty, let origin = pressOrigin, !draggedPastSlop {
            let current = currentQuartz()
            let proposed = CGPoint(x: current.x + stepX, y: current.y + stepY)
            if hypot(proposed.x - origin.x, proposed.y - origin.y) < clickSlop {
                return
            }
            draggedPastSlop = true
        }
        residualMouse.x -= stepX
        residualMouse.y -= stepY
        // NSEvent.mouseLocation stays in Cocoa space at the screen edge. CGEvent.location
        // flips there, so a downward stick keeps posting an off-screen point and the pointer sticks.
        let cocoa = NSEvent.mouseLocation
        let proposed = CGPoint(x: cocoa.x + stepX, y: cocoa.y - stepY)
        let clamped = clampToScreens(proposed)
        let quartz = quartzPoint(clamped)
        CGWarpMouseCursorPosition(quartz)
        cursorQuartz = quartz
        let type = dragType()
        let button = dragButton()
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: quartz, mouseButton: button) else { return }
        event.flags = modifierFlags
        if button == .center {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
        event.post(tap: .cghidEventTap)
    }

    private func postDelete(_ chunk: DeleteChunk) {
        let combo: KeyCombo
        switch chunk {
        case .character: combo = .backspace
        case .word: combo = KeyCombo(keyCode: 51, modifiers: .option)
        case .line: combo = KeyCombo(keyCode: 51, modifiers: .command)
        }
        postKey(combo, down: true)
        postKey(combo, down: false)
    }

    private func scroll(dx: Double, dy: Double) {
        residualScroll.x += dx
        residualScroll.y += dy
        let stepX = Int32(residualScroll.x.rounded(.towardZero))
        let stepY = Int32(residualScroll.y.rounded(.towardZero))
        guard stepX != 0 || stepY != 0 else { return }
        residualScroll.x -= Double(stepX)
        residualScroll.y -= Double(stepY)
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: stepY,
            wheel2: stepX,
            wheel3: 0
        ) else { return }
        event.flags = modifierFlags
        event.post(tap: .cghidEventTap)
    }

    private func setClicks(_ desired: Set<MouseButton>) {
        for button in MouseButton.allCases {
            let was = clicks.contains(button)
            let isDown = desired.contains(button)
            if isDown && !was { postClick(button, down: true) }
            if was && !isDown { postClick(button, down: false) }
        }
        clicks = desired
    }

    private func setHeldKeys(_ desired: Set<KeyCombo>) {
        let previous = heldKeys
        for combo in previous.subtracting(desired) where !combo.isModifierOnly {
            postKey(combo, down: false)
        }
        for combo in desired.subtracting(previous) where !combo.isModifierOnly {
            postKey(combo, down: true)
        }
        heldKeys = desired
        updateModifiers()
        let wantsFunction = desired.contains { $0.modifiers.contains(.function) || $0.keyCode == 63 }
        if wantsFunction && !functionDown {
            postFunction(down: true)
            functionDown = true
            functionAsserted = Date()
        } else if !wantsFunction && functionDown {
            postFunction(down: false)
            functionDown = false
        }
        syncModifierKeys()
        let repeating = desired.filter { !$0.isModifierOnly && $0.keyCode != 63 }
        for combo in keyRepeatAt.keys where !repeating.contains(combo) {
            keyRepeatAt[combo] = nil
        }
        for combo in repeating where keyRepeatAt[combo] == nil {
            keyRepeatAt[combo] = Date().addingTimeInterval(0.32)
        }
    }

    private func syncModifierKeys() {
        var wanted: [CGKeyCode: CGEventFlags] = [:]
        for combo in heldKeys where combo.isModifierOnly && !combo.modifiers.contains(.function) {
            wanted[modifierCode(for: combo)] = eventFlags(combo.modifiers)
        }
        for code in modifierKeysDown where wanted[code] == nil {
            postRaw(code, down: false, flags: [])
        }
        for (code, flags) in wanted where !modifierKeysDown.contains(code) {
            postRaw(code, down: true, flags: flags)
        }
        modifierKeysDown = Set(wanted.keys)
    }

    private func repeatHeldKeys() {
        let now = Date()
        for (combo, due) in keyRepeatAt where now >= due {
            postKey(combo, down: true, repeating: true)
            keyRepeatAt[combo] = now.addingTimeInterval(0.045)
        }
    }

    private func postRaw(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func sustainFunction() {
        guard functionDown, Date().timeIntervalSince(functionAsserted) > 0.2 else { return }
        postFlags(.maskSecondaryFn, keyCode: 63)
        functionAsserted = Date()
    }

    private func postFunction(down: Bool) {
        // A key-down for the Fn key is what makes macOS draw the volume meter. Wispr only needs the flag.
        postFlags(down ? .maskSecondaryFn : [], keyCode: 63)
    }

    private func tap(_ combo: KeyCombo) {
        if combo == .previousSpace { Spaces.step(-1); return }
        if combo == .nextSpace { Spaces.step(1); return }
        if combo == .missionControl { Spaces.stepFullscreen(1); return }
        if combo == .appWindows { Spaces.stepDesktop(1); return }
        if combo.isModifierOnly {
            postFlags(eventFlags(combo.modifiers), keyCode: modifierCode(for: combo))
            postFlags([], keyCode: modifierCode(for: combo))
            updateModifiers()
            return
        }
        postKey(combo, down: true)
        postKey(combo, down: false)
    }

    private func updateModifiers() {
        var flags = CGEventFlags()
        var code: CGKeyCode = 61
        for combo in heldKeys where combo.isModifierOnly && !combo.modifiers.contains(.function) {
            flags.formUnion(eventFlags(combo.modifiers))
            code = modifierCode(for: combo)
        }
        for combo in heldKeys where !combo.isModifierOnly {
            flags.formUnion(eventFlags(combo.modifiers))
        }
        guard flags != modifierFlags || (flags != [] && code != modifierKeyCode) else { return }
        modifierFlags = flags
        modifierKeyCode = code
        postFlags(flags, keyCode: code)
    }

    private func postKey(_ combo: KeyCombo, down: Bool, repeating: Bool = false) {
        guard let keyCode = combo.keyCode else { return }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        event.flags = eventFlags(combo.modifiers).union(modifierFlags)
        if repeating {
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        }
        event.post(tap: .cghidEventTap)
        if !down {
            postFlags(modifierFlags, keyCode: modifierKeyCode)
        }
    }

    private func postFlags(_ flags: CGEventFlags, keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else { return }
        event.type = .flagsChanged
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func postClick(_ button: MouseButton, down: Bool) {
        let type: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case .left:
            type = down ? .leftMouseDown : .leftMouseUp
            cgButton = .left
        case .right:
            type = down ? .rightMouseDown : .rightMouseUp
            cgButton = .right
        case .middle:
            type = down ? .otherMouseDown : .otherMouseUp
            cgButton = .center
        }
        let point: CGPoint
        if down {
            point = currentQuartz()
            pressOrigin = point
            draggedPastSlop = false
        } else if !draggedPastSlop, let origin = pressOrigin {
            point = origin
        } else {
            point = currentQuartz()
        }
        if !down, clicks.count <= 1 {
            pressOrigin = nil
            draggedPastSlop = false
        }
        CGWarpMouseCursorPosition(point)
        cursorQuartz = point
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: cgButton) else { return }
        event.flags = modifierFlags
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        if button == .middle {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
        event.post(tap: .cghidEventTap)
    }

    private func currentQuartz() -> CGPoint {
        cursorQuartz ?? quartzPoint(NSEvent.mouseLocation)
    }

    private func dragType() -> CGEventType {
        if clicks.contains(.left) { return .leftMouseDragged }
        if clicks.contains(.right) { return .rightMouseDragged }
        if clicks.contains(.middle) { return .otherMouseDragged }
        return .mouseMoved
    }

    private func dragButton() -> CGMouseButton {
        if clicks.contains(.right) && !clicks.contains(.left) { return .right }
        if clicks.contains(.middle) && !clicks.contains(.left) { return .center }
        return .left
    }

    private func clampToScreens(_ point: CGPoint) -> CGPoint {
        let frames = NSScreen.screens.map(\.frame)
        if frames.contains(where: { $0.contains(point) }) { return point }
        var best = point
        var bestDistance = Double.greatestFiniteMagnitude
        for frame in frames {
            let inset = frame.insetBy(dx: 1, dy: 1)
            let x = min(max(point.x, inset.minX), inset.maxX)
            let y = min(max(point.y, inset.minY), inset.maxY)
            let distance = hypot(Double(x - point.x), Double(y - point.y))
            if distance < bestDistance {
                bestDistance = distance
                best = CGPoint(x: x, y: y)
            }
        }
        return best
    }

    private func quartzPoint(_ cocoa: CGPoint) -> CGPoint {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        let height = primary?.frame.height ?? 0
        return CGPoint(x: cocoa.x, y: height - cocoa.y)
    }

    private func eventFlags(_ modifiers: KeyModifiers) -> CGEventFlags {
        var flags = CGEventFlags()
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    private func modifierCode(for combo: KeyCombo) -> CGKeyCode {
        if let keyCode = combo.keyCode, KeyCombo.modifierKeyCodes.contains(keyCode) {
            return CGKeyCode(keyCode)
        }
        if combo.modifiers.contains(.function) { return 63 }
        if combo.modifiers.contains(.option) { return combo.side == .left ? 58 : 61 }
        if combo.modifiers.contains(.command) { return combo.side == .left ? 55 : 54 }
        if combo.modifiers.contains(.control) { return combo.side == .left ? 59 : 62 }
        if combo.modifiers.contains(.shift) { return combo.side == .left ? 56 : 60 }
        return 61
    }
}
