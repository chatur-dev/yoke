import Foundation
import GameController
import IOKit
import IOKit.hid

final class GamepadHub {
    private(set) var name: String?
    private(set) var battery: Double?
    private(set) var state = PadState()
    private var controller: GCController?

    var isConnected: Bool { controller?.extendedGamepad != nil }

    func start() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(changed), name: .GCControllerDidConnect, object: nil)
        center.addObserver(self, selector: #selector(changed), name: .GCControllerDidDisconnect, object: nil)
        changed()
    }

    func poll() {
        if controller?.extendedGamepad == nil {
            controller = GCController.controllers().first { $0.extendedGamepad != nil }
            if let controller {
                name = controller.vendorName ?? controller.productCategory
            }
        }
        guard let pad = controller?.extendedGamepad else {
            state = PadState()
            return
        }
        var next = PadState()
        next.left = Stick(x: Double(pad.leftThumbstick.xAxis.value), y: Double(pad.leftThumbstick.yAxis.value))
        next.right = Stick(x: Double(pad.rightThumbstick.xAxis.value), y: Double(pad.rightThumbstick.yAxis.value))
        set(&next, .south, pad.buttonA.isPressed)
        set(&next, .east, pad.buttonB.isPressed)
        set(&next, .west, pad.buttonX.isPressed)
        set(&next, .north, pad.buttonY.isPressed)
        set(&next, .leftBumper, pad.leftShoulder.isPressed)
        set(&next, .rightBumper, pad.rightShoulder.isPressed)
        next.amount[.leftTrigger] = Double(pad.leftTrigger.value)
        next.amount[.rightTrigger] = Double(pad.rightTrigger.value)
        set(&next, .dpadUp, pad.dpad.up.isPressed)
        set(&next, .dpadDown, pad.dpad.down.isPressed)
        set(&next, .dpadLeft, pad.dpad.left.isPressed)
        set(&next, .dpadRight, pad.dpad.right.isPressed)
        let named = controller?.physicalInputProfile.buttons
        func namedDown(_ key: String) -> Bool { named?[key]?.isPressed == true }
        if namedDown("Direction Pad Up") { set(&next, .dpadUp, true) }
        if namedDown("Direction Pad Down") { set(&next, .dpadDown, true) }
        if namedDown("Direction Pad Left") { set(&next, .dpadLeft, true) }
        if namedDown("Direction Pad Right") { set(&next, .dpadRight, true) }
        if let button = pad.leftThumbstickButton { set(&next, .leftStickClick, button.isPressed) }
        if let button = pad.rightThumbstickButton { set(&next, .rightStickClick, button.isPressed) }
        set(&next, .menu, pad.buttonMenu.isPressed)
        if let button = pad.buttonOptions { set(&next, .back, button.isPressed) }
        state = next
        if let level = controller?.battery?.batteryLevel, level >= 0 {
            battery = Double(level)
        }
    }

    @objc private func changed() {
        controller = GCController.controllers().first { $0.extendedGamepad != nil }
        if let controller {
            name = controller.vendorName ?? controller.productCategory
            controller.extendedGamepad?.valueChangedHandler = { _, _ in }
        } else {
            name = nil
            battery = nil
            state = PadState()
        }
    }

    private func set(_ pad: inout PadState, _ control: PadControl, _ down: Bool) {
        if down { pad.amount[control] = 1 }
    }
}

final class HIDHub {
    private var manager: IOHIDManager?
    private var devices: [HIDPad] = []
    var onButtonDown: ((Int) -> Void)?
    var onInput: (() -> Void)?

    var isConnected: Bool { primary != nil }
    var name: String? { primary?.name }
    var state: PadState { primary?.state ?? PadState() }

    private var primary: HIDPad? { devices.first }
    var hasInput: Bool { devices.contains { $0.hasInput } }

    func start(layout: @escaping (Int) -> PadControl?) {
        self.layout = layout
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        let pageKey = kIOHIDDeviceUsagePageKey as String
        let usageKey = kIOHIDDeviceUsageKey as String
        let match: [[String: Any]] = [
            [pageKey: NSNumber(value: HIDPage.desktop), usageKey: NSNumber(value: HIDPage.gamePad)],
            [pageKey: NSNumber(value: HIDPage.desktop), usageKey: NSNumber(value: HIDPage.joystick)],
            [pageKey: NSNumber(value: HIDPage.desktop), usageKey: NSNumber(value: HIDPage.multiAxis)],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, match as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDHub>.fromOpaque(context).takeUnretainedValue().add(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDHub>.fromOpaque(context).takeUnretainedValue().remove(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.layout = layout
    }

    func setLayout(_ layout: @escaping (Int) -> PadControl?) {
        self.layout = layout
        for device in devices {
            device.control = layout
        }
    }

    private var layout: (Int) -> PadControl? = { HIDLayout.directInput[$0] }

    private func add(_ device: IOHIDDevice) {
        let vendor = (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue ?? 0
        if vendor == 0x05AC { return }
        let pad = HIDPad(device: device, control: layout)
        pad.onButtonDown = { [weak self] usage in self?.onButtonDown?(usage) }
        pad.onInput = { [weak self] in self?.onInput?() }
        devices.append(pad)
    }

    private func remove(_ device: IOHIDDevice) {
        let location = (IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? NSNumber)?.intValue
        devices.removeAll { $0.location == location }
    }
}

private enum HIDPage {
    static let desktop: UInt32 = 0x01
    static let button: UInt32 = 0x09
    static let joystick: UInt32 = 0x04
    static let gamePad: UInt32 = 0x05
    static let multiAxis: UInt32 = 0x08
    static let x: UInt32 = 0x30
    static let y: UInt32 = 0x31
    static let z: UInt32 = 0x32
    static let rx: UInt32 = 0x33
    static let ry: UInt32 = 0x34
    static let rz: UInt32 = 0x35
    static let hat: UInt32 = 0x39
}

private final class HIDPad {
    let device: IOHIDDevice
    let location: Int
    let name: String
    var control: (Int) -> PadControl?
    var state = PadState()
    var hasInput = false
    var onButtonDown: ((Int) -> Void)?
    var onInput: (() -> Void)?
    private var axes: [AxisRole: Axis] = [:]
    private var downButtons: Set<Int> = []

    init(device: IOHIDDevice, control: @escaping (Int) -> PadControl?) {
        self.device = device
        self.control = control
        location = (IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? NSNumber)?.intValue ?? 0
        name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Controller"
        classify()
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(device, { context, _, _, value in
            guard let context else { return }
            Unmanaged<HIDPad>.fromOpaque(context).takeUnretainedValue().received(value)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }

    private func classify() {
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] ?? []
        for element in elements {
            let page = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let min = IOHIDElementGetLogicalMin(element)
            let max = IOHIDElementGetLogicalMax(element)
            guard page == HIDPage.desktop else { continue }
            let axis = Axis(element: element, lower: Double(min), upper: Double(max))
            switch usage {
            case UInt32(HIDPage.x): claim(.leftX, axis, prefer: true)
            case UInt32(HIDPage.y): claim(.leftY, axis, prefer: true)
            case UInt32(HIDPage.rx): claim(.rightX, axis, prefer: true)
            case UInt32(HIDPage.ry): claim(.rightY, axis, prefer: true)
            case UInt32(HIDPage.z):
                if min < 0 { claim(.rightX, axis, prefer: false) } else { claim(.leftTrigger, axis, prefer: true) }
            case UInt32(HIDPage.rz):
                if min < 0 { claim(.rightY, axis, prefer: false) } else { claim(.rightTrigger, axis, prefer: true) }
            case UInt32(HIDPage.hat): claim(.hat, axis, prefer: true)
            default: break
            }
        }
    }

    private func claim(_ role: AxisRole, _ axis: Axis, prefer: Bool) {
        if axes[role] == nil || prefer { axes[role] = axis }
    }

    private func received(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = Int(IOHIDElementGetUsage(element))
        let raw = Double(IOHIDValueGetIntegerValue(value))
        if page == HIDPage.button {
            let pressed = IOHIDValueGetIntegerValue(value) != 0
            hasInput = true
            if pressed && !downButtons.contains(usage) {
                downButtons.insert(usage)
                onButtonDown?(usage)
            } else if !pressed {
                downButtons.remove(usage)
            }
            if let control = resolved(usage) {
                state.amount[control] = pressed ? 1 : 0
            }
            onInput?()
            return
        }
        guard page == HIDPage.desktop else { return }
        hasInput = true
        if axes[.hat]?.element == element {
            applyHat(raw, element: element)
            onInput?()
            return
        }
        for (role, axis) in axes where axis.element == element {
            let shaped = axis.normalize(raw, role: role)
            switch role {
            case .leftX: state.left.x = shaped
            case .leftY: state.left.y = shaped
            case .rightX: state.right.x = shaped
            case .rightY: state.right.y = shaped
            case .leftTrigger: state.amount[.leftTrigger] = shaped
            case .rightTrigger: state.amount[.rightTrigger] = shaped
            case .hat: break
            }
        }
        onInput?()
    }

    private func resolved(_ usage: Int) -> PadControl? {
        let mapped = control(usage)
        switch usage {
        case 12: return .dpadUp
        case 13: return .dpadDown
        case 14: return .dpadLeft
        case 15: return .dpadRight
        default: break
        }
        let triggersAreAxes = axes[.leftTrigger] != nil || axes[.rightTrigger] != nil
        guard triggersAreAxes else { return mapped }
        switch usage {
        case 7 where mapped == .leftTrigger: return .back
        case 8 where mapped == .rightTrigger: return .menu
        case 9 where mapped == .back: return .leftStickClick
        case 10 where mapped == .menu: return .rightStickClick
        default: return mapped
        }
    }

    private func applyHat(_ raw: Double, element: IOHIDElement) {
        for control in [PadControl.dpadUp, .dpadDown, .dpadLeft, .dpadRight] {
            state.amount[control] = 0
        }
        var value = Int(raw)
        if IOHIDElementGetLogicalMin(element) == 1 { value -= 1 }
        guard (0..<8).contains(value) else { return }
        if [0, 1, 7].contains(value) { state.amount[.dpadUp] = 1 }
        if [1, 2, 3].contains(value) { state.amount[.dpadRight] = 1 }
        if [3, 4, 5].contains(value) { state.amount[.dpadDown] = 1 }
        if [5, 6, 7].contains(value) { state.amount[.dpadLeft] = 1 }
    }
}

private enum AxisRole {
    case leftX, leftY, rightX, rightY, leftTrigger, rightTrigger, hat
}

private struct Axis {
    let element: IOHIDElement
    let lower: Double
    let upper: Double

    func normalize(_ raw: Double, role: AxisRole) -> Double {
        let span = upper - lower
        guard span != 0 else { return 0 }
        switch role {
        case .leftTrigger, .rightTrigger:
            return Swift.min(1, Swift.max(0, (raw - lower) / span))
        case .hat:
            return raw
        default:
            let mid = (lower + upper) / 2
            return Swift.min(1, Swift.max(-1, (raw - mid) / (span / 2)))
        }
    }
}
