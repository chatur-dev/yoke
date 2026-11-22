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

    init() {
        source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
    }

    func apply(_ frame: FrameOutput) {
        move(dx: frame.mouseX, dy: frame.mouseY)
        scroll(dx: frame.scrollX, dy: frame.scrollY)
        setClicks(frame.clicks)
        setHeldKeys(frame.heldKeys)
        for combo in frame.tappedKeys {
            tap(combo)
        }
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
        residualMouse.x -= stepX
        residualMouse.y -= stepY
        let next = CGPoint(x: location().x + stepX, y: location().y + stepY)
        let type = dragType()
        let button = dragButton()
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: next, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(stepX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(stepY))
        if button == .center {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
        event.post(tap: .cghidEventTap)
    }

    private func scroll(dx: Double, dy: Double) {
        residualScroll.x += dx
        residualScroll.y += dy
        let stepX = Int32(residualScroll.x.rounded(.towardZero))
        let stepY = Int32(residualScroll.y.rounded(.towardZero))
        guard stepX != 0 || stepY != 0 else { return }
        residualScroll.x -= Double(stepX)
        residualScroll.y -= Double(stepY)
        CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: stepY,
            wheel2: stepX,
            wheel3: 0
        )?.post(tap: .cghidEventTap)
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
    }

    private func tap(_ combo: KeyCombo) {
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
        for combo in heldKeys where combo.isModifierOnly || combo.modifiers.contains(.function) {
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

    private func postKey(_ combo: KeyCombo, down: Bool) {
        guard let keyCode = combo.keyCode else { return }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        event.flags = eventFlags(combo.modifiers).union(modifierFlags)
        event.post(tap: .cghidEventTap)
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
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location(), mouseButton: cgButton) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        if button == .middle {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
        event.post(tap: .cghidEventTap)
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

    private func location() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
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
