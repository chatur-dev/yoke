import Foundation

struct Stick: Equatable {
    var x: Double
    var y: Double

    static let zero = Stick(x: 0, y: 0)

    var magnitude: Double { (x * x + y * y).squareRoot() }
}

enum MouseButton: String, Codable, CaseIterable, Equatable {
    case left, right, middle
}

struct KeyModifiers: OptionSet, Hashable, Codable {
    let rawValue: Int

    static let shift = KeyModifiers(rawValue: 1 << 0)
    static let control = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)
    static let function = KeyModifiers(rawValue: 1 << 4)
}

enum KeySide: String, Codable, Hashable {
    case left, right
}

struct KeyCombo: Equatable, Hashable, Codable {
    var keyCode: Int?
    var modifiers: KeyModifiers = []
    var side: KeySide?

    static let rightOption = KeyCombo(modifiers: .option, side: .right)
    static let leftOption = KeyCombo(modifiers: .option, side: .left)
    static let command = KeyCombo(modifiers: .command, side: .left)
    static let control = KeyCombo(modifiers: .control, side: .left)
    static let shift = KeyCombo(modifiers: .shift, side: .left)
    static let function = KeyCombo(keyCode: 63, modifiers: .function)
    static let controlOption = KeyCombo(modifiers: [.control, .option])
    static let optionF13 = KeyCombo(keyCode: 105, modifiers: .option)
    static let missionControl = KeyCombo(keyCode: 126, modifiers: .control)
    static let spotlight = KeyCombo(keyCode: 49, modifiers: .command)
    static let backspace = KeyCombo(keyCode: 51)
    static let forwardDelete = KeyCombo(keyCode: 117)
    static let selectLeft = KeyCombo(keyCode: 123, modifiers: .shift)
    static let selectWord = KeyCombo(keyCode: 123, modifiers: [.shift, .option])
    static let previousSpace = KeyCombo(keyCode: 123, modifiers: .control)
    static let nextSpace = KeyCombo(keyCode: 124, modifiers: .control)
    static let appWindows = KeyCombo(keyCode: 125, modifiers: .control)
    static let enter = KeyCombo(keyCode: 36)
    static let send = KeyCombo(keyCode: 36, modifiers: .command)
    static let arrowUp = KeyCombo(keyCode: 126)
    static let arrowDown = KeyCombo(keyCode: 125)
    static let arrowLeft = KeyCombo(keyCode: 123)
    static let arrowRight = KeyCombo(keyCode: 124)

    var isModifierOnly: Bool {
        guard let keyCode else { return true }
        return KeyCombo.modifierKeyCodes.contains(keyCode)
    }

    static let modifierKeyCodes: Set<Int> = [56, 57, 58, 59, 60, 61, 62, 54, 55, 63]
}

enum PadControl: String, Codable, CaseIterable, Equatable, Hashable {
    case leftStick, rightStick
    case leftStickClick, rightStickClick
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case south, east, west, north
    case leftBumper, rightBumper
    case leftTrigger, rightTrigger
    case menu, back
}

enum Action: Equatable, Codable {
    case mouse
    case scroll
    case precision
    case click(MouseButton)
    case hold(KeyCombo)
    case tap(KeyCombo)
    case dictate
    case suspend
    case none
}

struct Feel: Equatable, Codable {
    var deadzone: Double = 0.14
    var exponent: Double = 1.75
    var maxSpeed: Double = 1600
    var precisionScale: Double = 0.22
    var scrollSpeed: Double = 900
    var triggerThreshold: Double = 0.4
    var invertMouseY: Bool = false
    var invertScroll: Bool = false

    static let bed = Feel()
}

struct PadBinding: Equatable, Codable {
    var control: PadControl
    var action: Action
}

struct Profile: Equatable, Codable {
    var name: String
    var bindings: [PadBinding]
    var feel: Feel
    var dictation: KeyCombo
    var hidButtons: [Int: PadControl]

    static let bed = Profile(
        name: "Bed",
        bindings: [
            PadBinding(control: .leftStick, action: .mouse),
            PadBinding(control: .rightStick, action: .scroll),
            PadBinding(control: .leftTrigger, action: .precision),
            PadBinding(control: .rightTrigger, action: .none),
            PadBinding(control: .leftBumper, action: .hold(.leftOption)),
            PadBinding(control: .rightBumper, action: .dictate),
            PadBinding(control: .south, action: .click(.left)),
            PadBinding(control: .east, action: .click(.right)),
            PadBinding(control: .west, action: .tap(.enter)),
            PadBinding(control: .north, action: .tap(.send)),
            PadBinding(control: .leftStickClick, action: .click(.left)),
            PadBinding(control: .rightStickClick, action: .click(.right)),
            PadBinding(control: .dpadUp, action: .tap(.missionControl)),
            PadBinding(control: .dpadDown, action: .tap(.appWindows)),
            PadBinding(control: .dpadLeft, action: .tap(.previousSpace)),
            PadBinding(control: .dpadRight, action: .tap(.nextSpace)),
            PadBinding(control: .menu, action: .suspend),
            PadBinding(control: .back, action: .hold(.backspace)),
        ],
        feel: .bed,
        dictation: .function,
        hidButtons: [:]
    )

    func action(for control: PadControl) -> Action {
        bindings.first { $0.control == control }?.action ?? .none
    }

    mutating func setAction(_ action: Action, for control: PadControl) {
        if let index = bindings.firstIndex(where: { $0.control == control }) {
            bindings[index].action = action
        } else {
            bindings.append(PadBinding(control: control, action: action))
        }
    }

    func hidControl(forButton usage: Int) -> PadControl? {
        if let mapped = hidButtons[usage] { return mapped }
        return HIDLayout.directInput[usage]
    }
}

enum HIDLayout {
    /// Generic Bluetooth pads, including most Evo Fox units, speak DirectInput order.
    static let directInput: [Int: PadControl] = [
        1: .south, 2: .east, 3: .west, 4: .north,
        5: .leftBumper, 6: .rightBumper,
        7: .leftTrigger, 8: .rightTrigger,
        9: .back, 10: .menu,
        11: .leftStickClick, 12: .rightStickClick,
    ]
}

struct PadState: Equatable {
    var left = Stick.zero
    var right = Stick.zero
    var amount: [PadControl: Double] = [:]

    func value(_ control: PadControl) -> Double {
        amount[control] ?? 0
    }
}

struct FrameOutput: Equatable {
    var mouseX: Double = 0
    var mouseY: Double = 0
    var scrollX: Double = 0
    var scrollY: Double = 0
    var clicks: Set<MouseButton> = []
    var heldKeys: Set<KeyCombo> = []
    var tappedKeys: [KeyCombo] = []
    var suspended = false
    var precision = false

    static let empty = FrameOutput()
}

struct Mapper {
    var profile: Profile
    var suspended = false
    private var wasDown: Set<PadControl> = []
    private var lowFrames: [PadControl: Int] = [:]

    init(profile: Profile = .bed) {
        self.profile = profile
    }

    mutating func step(_ pad: PadState, dt rawDT: Double) -> FrameOutput {
        let dt = min(max(rawDT, 0), 0.05)
        let down = Set(PadControl.allCases.filter { isDown($0, pad) })
        let rising = down.subtracting(wasDown)
        wasDown = down

        if let suspendControl = PadControl.allCases.first(where: { profile.action(for: $0) == .suspend }),
           rising.contains(suspendControl) {
            suspended.toggle()
        }

        guard !suspended else {
            return FrameOutput(suspended: true)
        }

        var output = FrameOutput()
        output.precision = down.contains { profile.action(for: $0) == .precision }

        if profile.action(for: .leftStick) == .mouse {
            let velocity = StickMath.mouseVelocity(stick: pad.left, feel: profile.feel, precision: output.precision)
            output.mouseX += velocity.x * dt
            output.mouseY += velocity.y * dt
        } else if profile.action(for: .leftStick) == .scroll {
            let velocity = StickMath.scrollVelocity(stick: pad.left, feel: profile.feel)
            output.scrollX += velocity.x * dt
            output.scrollY += velocity.y * dt
        }
        if profile.action(for: .rightStick) == .scroll {
            let velocity = StickMath.scrollVelocity(stick: pad.right, feel: profile.feel)
            output.scrollX += velocity.x * dt
            output.scrollY += velocity.y * dt
        } else if profile.action(for: .rightStick) == .mouse {
            let velocity = StickMath.mouseVelocity(stick: pad.right, feel: profile.feel, precision: output.precision)
            output.mouseX += velocity.x * dt
            output.mouseY += velocity.y * dt
        }

        for control in down where control != .leftStick && control != .rightStick {
            switch profile.action(for: control) {
            case .click(let button):
                output.clicks.insert(button)
            case .hold(let combo):
                output.heldKeys.insert(combo)
            case .dictate:
                output.heldKeys.insert(profile.dictation)
            default:
                break
            }
        }
        for control in rising where control != .leftStick && control != .rightStick {
            if case .tap(let combo) = profile.action(for: control) {
                output.tappedKeys.append(combo)
            }
        }
        return output
    }

    private mutating func isDown(_ control: PadControl, _ pad: PadState) -> Bool {
        if control == .leftStick || control == .rightStick { return false }
        if pad.value(control) >= profile.feel.triggerThreshold {
            lowFrames[control] = 0
            return true
        }
        let lows = (lowFrames[control] ?? 0) + 1
        lowFrames[control] = lows
        return wasDown.contains(control) && lows < 5
    }
}

enum StickMath {
    /// Stick y is positive up. Mouse velocity y is positive down, in points per second.
    static func mouseVelocity(stick: Stick, feel: Feel, precision: Bool) -> Stick {
        var shaped = curve(stick, deadzone: feel.deadzone, exponent: feel.exponent)
        if feel.invertMouseY { shaped.y = -shaped.y }
        let speed = feel.maxSpeed * (precision ? feel.precisionScale : 1)
        return Stick(x: shaped.x * speed, y: -shaped.y * speed)
    }

    /// Scroll velocity y is positive up, in pixels per second.
    static func scrollVelocity(stick: Stick, feel: Feel) -> Stick {
        var shaped = curve(stick, deadzone: feel.deadzone, exponent: feel.exponent)
        if feel.invertScroll { shaped.y = -shaped.y }
        return Stick(x: shaped.x * feel.scrollSpeed, y: shaped.y * feel.scrollSpeed)
    }

    static func curve(_ stick: Stick, deadzone: Double, exponent: Double) -> Stick {
        let x = min(1, max(-1, stick.x))
        let y = min(1, max(-1, stick.y))
        let mag = (x * x + y * y).squareRoot()
        guard mag > deadzone, mag > 0, deadzone < 1 else { return .zero }
        let scaled = min(1, (mag - deadzone) / (1 - deadzone))
        let shaped = pow(scaled, exponent) / mag
        return Stick(x: x * shaped, y: y * shaped)
    }
}

enum ProfileStore {
    static func load(from url: URL) -> Profile {
        guard let data = try? Data(contentsOf: url),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return .bed
        }
        return profile
    }

    static func save(_ profile: Profile, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(profile)
        try data.write(to: url, options: .atomic)
    }
}
