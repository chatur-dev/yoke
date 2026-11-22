import AppKit
import SwiftUI

struct PopoverView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                if !model.trusted { permission }
                if model.deleteMode { deleteBanner }
                if model.controllerName == nil {
                    empty
                } else {
                    driving
                    speed
                    talk
                    if model.source == "Generic" { generic }
                    bindings
                }
                Divider()
                footer
            }
            .padding(14)
            .frame(width: 320, alignment: .leading)
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yoke").font(.headline)
                Text(model.controllerName ?? "No controller")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            stick
            if let battery = model.battery {
                Text("\(Int((battery * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var stick: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1)
            Circle().fill(Color.primary)
                .frame(width: 7, height: 7)
                .offset(x: model.preview.x * 12, y: -model.preview.y * 12)
        }
        .frame(width: 32, height: 32)
        .accessibilityLabel("Left stick")
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Yoke can't move the pointer until Accessibility is on.")
                .font(.callout)
            Button("Allow Accessibility") { model.requestAccessibility() }
        }
    }

    private var empty: some View {
        Text("Pair the Evo Fox, or any other pad, in System Settings → Bluetooth. Yoke picks it up on its own.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var deleteBanner: some View {
        Text("Delete mode. Push the scroll stick to erase. A hard push takes words, then the line. Hold LT to erase one character at a time. Press Back again to leave.")
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var driving: some View {
        Toggle("Driving", isOn: Binding(
            get: { !model.suspended },
            set: { model.setSuspended(!$0) }
        ))
        .toggleStyle(.switch)
    }

    private var speed: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pointer speed").font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { model.profile.feel.maxSpeed },
                set: { model.setSpeed($0) }
            ), in: 400...2800)
            Text("Scroll speed").font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { model.profile.feel.scrollSpeed },
                set: { model.setScrollSpeed($0) }
            ), in: 200...2800)
            Toggle("Invert stick", isOn: Binding(
                get: { model.profile.feel.invertMouseY },
                set: { model.setInvertMouseY($0) }
            ))
            .toggleStyle(.checkbox)
            Toggle("Invert scroll", isOn: Binding(
                get: { model.profile.feel.invertScroll },
                set: { model.setInvertScroll($0) }
            ))
            .toggleStyle(.checkbox)
        }
    }

    private var talk: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Talk").font(.callout)
                Spacer()
                Picker("Talk key", selection: Binding(
                    get: { TalkKey.matching(model.profile.dictation) },
                    set: { model.setDictation($0.combo) }
                )) {
                    ForEach(TalkKey.allCases) { key in
                        Text(key.label).tag(key)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
            }
            Text("Hold RB to talk, and let go to stop. Push the scroll stick to scroll. A sideways swipe goes back or forward, the same as two fingers on a trackpad. Plus left and right move the desktop on the screen the pointer is on.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var generic: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.hasSeenInput {
                Text("Pad is connected but silent. Allow Input Monitoring, then reconnect it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Input Monitoring") { model.openInputMonitoring() }
            }
            if let capture = model.capture {
                Text("Press \(capture.label)").font(.callout)
                Button("Cancel calibration") { model.cancelCalibration() }
            } else {
                HStack {
                    Button("Calibrate buttons") { model.beginCalibration() }
                    if let lastButton = model.lastButton {
                        Text("Last \(lastButton)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var bindings: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(bindingRows, id: \.self) { control in
                HStack {
                    Text(control.label)
                        .font(.callout)
                        .frame(width: 118, alignment: .leading)
                    Spacer(minLength: 8)
                    Picker(control.label, selection: Binding(
                        get: { Choice.matching(model.profile.action(for: control), control: control) },
                        set: { model.setAction($0.action(for: control), for: control) }
                    )) {
                        ForEach(Choice.options(for: control)) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 130)
                }
            }
        }
    }

    private var bindingRows: [PadControl] {
        [.dpadLeft, .dpadRight, .dpadUp, .dpadDown, .ml, .mr, .west, .north, .south, .east, .back, .rightBumper, .leftBumper, .leftTrigger, .rightTrigger, .menu]
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at login", isOn: Binding(
                get: { model.loginEnabled },
                set: { model.setLoginItem($0) }
            ))
            .toggleStyle(.checkbox)
            if let loginError = model.loginError {
                Text(loginError).font(.caption).foregroundStyle(.secondary)
            }
            Button("Quit Yoke") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }
}

private enum TalkKey: String, CaseIterable, Identifiable {
    case rightOption, function, controlOption, optionF13
    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightOption: "Right Option"
        case .function: "Fn"
        case .controlOption: "Control + Option"
        case .optionF13: "Option + F13"
        }
    }

    var combo: KeyCombo {
        switch self {
        case .rightOption: .rightOption
        case .function: .function
        case .controlOption: .controlOption
        case .optionF13: .optionF13
        }
    }

    static func matching(_ combo: KeyCombo) -> TalkKey {
        allCases.first { $0.combo == combo } ?? .rightOption
    }
}

private enum Choice: String, CaseIterable, Identifiable {
    case pointer, scroll, precision
    case leftClick, rightClick, middleClick
    case talk, option, command, control, shift, function
    case missionControl, spotlight, previousSpace, nextSpace, appWindows, enter, send, focusText, paste, deleteMode, backspace, delete, selectBack, arrow, suspend, none
    var id: String { rawValue }

    var label: String {
        switch self {
        case .pointer: "Pointer"
        case .scroll: "Scroll"
        case .precision: "Precision"
        case .leftClick: "Left click"
        case .rightClick: "Right click"
        case .middleClick: "Middle click"
        case .talk: "Talk"
        case .option: "Option"
        case .command: "Command"
        case .control: "Control"
        case .shift: "Shift"
        case .function: "Function"
        case .missionControl: "Mission Control"
        case .spotlight: "Spotlight"
        case .previousSpace: "Previous space"
        case .nextSpace: "Next space"
        case .appWindows: "App windows"
        case .enter: "Enter"
        case .send: "Send"
        case .focusText: "Focus text"
        case .paste: "Paste"
        case .deleteMode: "Delete mode"
        case .backspace: "Backspace"
        case .delete: "Delete"
        case .selectBack: "Select back"
        case .arrow: "Arrow"
        case .suspend: "Suspend"
        case .none: "None"
        }
    }

    static func options(for control: PadControl) -> [Choice] {
        if control == .leftStick || control == .rightStick {
            return [.pointer, .scroll, .none]
        }
        return [.talk, .deleteMode, .focusText, .paste, .enter, .send, .previousSpace, .nextSpace, .missionControl, .appWindows, .backspace, .delete, .selectBack, .precision, .leftClick, .rightClick, .middleClick, .option, .command, .control, .shift, .function, .spotlight, .arrow, .suspend, .none]
    }

    static func matching(_ action: Action, control: PadControl) -> Choice {
        switch action {
        case .mouse: .pointer
        case .scroll: .scroll
        case .precision: .precision
        case .click(.left): .leftClick
        case .click(.right): .rightClick
        case .click(.middle): .middleClick
        case .dictate: .talk
        case .hold(let combo) where combo == .leftOption: .option
        case .hold(let combo) where combo == .command: .command
        case .hold(let combo) where combo == .control: .control
        case .hold(let combo) where combo == .shift: .shift
        case .hold(let combo) where combo == .function: .function
        case .hold(let combo) where combo == control.arrowCombo: .arrow
        case .tap(let combo) where combo == .missionControl: .missionControl
        case .tap(let combo) where combo == .spotlight: .spotlight
        case .tap(let combo) where combo == .previousSpace: .previousSpace
        case .tap(let combo) where combo == .nextSpace: .nextSpace
        case .tap(let combo) where combo == .appWindows: .appWindows
        case .tap(let combo) where combo == .enter: .enter
        case .tap(let combo) where combo == .send: .send
        case .hold(let combo) where combo == .backspace: .backspace
        case .hold(let combo) where combo == .forwardDelete: .delete
        case .hold(let combo) where combo == .selectLeft || combo == .selectWord: .selectBack
        case .deleteMode: .deleteMode
        case .focusText: .focusText
        case .tap(let combo) where combo == .paste: .paste
        case .suspend: .suspend
        case .none: .none
        default: .none
        }
    }

    func action(for control: PadControl) -> Action {
        switch self {
        case .pointer: .mouse
        case .scroll: .scroll
        case .precision: .precision
        case .leftClick: .click(.left)
        case .rightClick: .click(.right)
        case .middleClick: .click(.middle)
        case .talk: .dictate
        case .option: .hold(.leftOption)
        case .command: .hold(.command)
        case .control: .hold(.control)
        case .shift: .hold(.shift)
        case .function: .hold(.function)
        case .missionControl: .tap(.missionControl)
        case .spotlight: .tap(.spotlight)
        case .previousSpace: .tap(.previousSpace)
        case .nextSpace: .tap(.nextSpace)
        case .appWindows: .tap(.appWindows)
        case .enter: .tap(.enter)
        case .send: .tap(.send)
        case .focusText: .focusText
        case .paste: .tap(.paste)
        case .deleteMode: .deleteMode
        case .backspace: .hold(.backspace)
        case .delete: .hold(.forwardDelete)
        case .selectBack: .hold(.selectWord)
        case .arrow: .hold(control.arrowCombo ?? .arrowUp)
        case .suspend: .suspend
        case .none: .none
        }
    }
}

private extension PadControl {
    var label: String {
        switch self {
        case .leftStick: "Left stick"
        case .rightStick: "Right stick"
        case .leftStickClick: "L3"
        case .rightStickClick: "R3"
        case .dpadLeft: "Plus left"
        case .dpadRight: "Plus right"
        case .dpadUp: "Plus up"
        case .dpadDown: "Plus down"
        case .south: "A / Cross"
        case .east: "B / Circle"
        case .west: "X / Enter"
        case .north: "Y / Focus"
        case .ml: "ML"
        case .mr: "MR"
        case .leftBumper: "LB"
        case .rightBumper: "RB"
        case .leftTrigger: "LT"
        case .rightTrigger: "RT"
        case .menu: "Start"
        case .back: "Back / Select"
        }
    }

    var arrowCombo: KeyCombo? {
        switch self {
        case .dpadUp: .arrowUp
        case .dpadDown: .arrowDown
        case .dpadLeft: .arrowLeft
        case .dpadRight: .arrowRight
        default: nil
        }
    }
}
