import ApplicationServices
import AppKit
import Foundation
import Observation
import ServiceManagement

@Observable
final class AppModel {
    var profile: Profile
    var suspended = false
    var controllerName: String?
    var battery: Double?
    var source = "Waiting"
    var trusted = false
    var hasSeenInput = false
    var lastButton: Int?
    var capture: PadControl?
    var preview = Stick.zero
    var loginError: String?

    private let storeURL: URL
    private let injector = EventInjector()
    private var mapper: Mapper
    private let gamepads = GamepadHub()
    private let hid = HIDHub()
    private var timer: Timer?
    private var lastTick = Date()
    private var uiAccum = 0.0
    private let captureOrder: [PadControl] = [
        .south, .east, .west, .north,
        .leftBumper, .rightBumper, .leftTrigger, .rightTrigger,
        .back, .menu, .leftStickClick, .rightStickClick,
    ]

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Yoke", isDirectory: true)
        storeURL = directory.appendingPathComponent("profile.json")
        let loaded = ProfileStore.load(from: storeURL)
        profile = loaded
        mapper = Mapper(profile: loaded)
        trusted = AXIsProcessTrusted()
    }

    func start() {
        hid.onButtonDown = { [weak self] usage in self?.noteButton(usage) }
        hid.onInput = { [weak self] in self?.hasSeenInput = true }
        hid.start { [weak self] usage in
            self?.profile.hidControl(forButton: usage)
        }
        gamepads.start()
        lastTick = Date()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        injector.releaseAll()
    }

    var iconFilled: Bool { controllerName != nil && !suspended }

    var tooltip: String {
        guard let controllerName else { return "Yoke — no controller" }
        if suspended { return "Yoke — \(controllerName) suspended" }
        return "Yoke — \(controllerName)"
    }

    func setSuspended(_ value: Bool) {
        suspended = value
        mapper.suspended = value
        if value { injector.releaseAll() }
    }

    func setSpeed(_ value: Double) {
        profile.feel.maxSpeed = value
        persist()
    }

    func setScrollSpeed(_ value: Double) {
        profile.feel.scrollSpeed = value
        persist()
    }

    func setInvertMouseY(_ value: Bool) {
        profile.feel.invertMouseY = value
        persist()
    }

    func setInvertScroll(_ value: Bool) {
        profile.feel.invertScroll = value
        persist()
    }

    func setDictation(_ combo: KeyCombo) {
        profile.dictation = combo
        persist()
    }

    func setAction(_ action: Action, for control: PadControl) {
        profile.setAction(action, for: control)
        persist()
    }

    func setLoginItem(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginError = "Move Yoke to /Applications, then try again."
        }
    }

    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func beginCalibration() {
        if profile.hidButtons.isEmpty {
            profile.hidButtons = HIDLayout.directInput
        }
        capture = captureOrder.first
        persist()
    }

    func cancelCalibration() {
        capture = nil
    }

    private func noteButton(_ usage: Int) {
        lastButton = usage
        hasSeenInput = true
        guard let capture else { return }
        var map = profile.hidButtons
        for key in map.filter({ $0.value == capture }).map(\.key) {
            map[key] = nil
        }
        map[usage] = capture
        profile.hidButtons = map
        if let index = captureOrder.firstIndex(of: capture), index + 1 < captureOrder.count {
            self.capture = captureOrder[index + 1]
        } else {
            self.capture = nil
        }
        hid.setLayout { [weak self] usage in
            self?.profile.hidControl(forButton: usage)
        }
        persist()
    }

    private func tick() {
        let now = Date()
        let dt = min(0.05, now.timeIntervalSince(lastTick))
        lastTick = now
        gamepads.poll()
        let reading = currentReading()
        controllerName = reading?.name
        battery = reading?.battery
        source = reading?.source ?? "Waiting"
        let pad = reading?.state ?? PadState()
        if pad != PadState() { hasSeenInput = true }
        preview = pad.left
        mapper.profile = profile
        mapper.suspended = suspended
        let wasSuspended = suspended
        let frame = mapper.step(pad, dt: dt)
        if capture != nil {
            suspended = wasSuspended
            mapper.suspended = wasSuspended
        } else {
            suspended = mapper.suspended
        }
        if controllerName == nil || capture != nil {
            injector.releaseAll()
        } else {
            injector.apply(frame)
        }
        uiAccum += dt
        if uiAccum > 1.0 / 15 {
            uiAccum = 0
            trusted = AXIsProcessTrusted()
        }
    }

    private func currentReading() -> (name: String, state: PadState, battery: Double?, source: String)? {
        if hid.isConnected, hid.hasInput || !gamepads.isConnected, let name = hid.name {
            return (name, hid.state, gamepads.battery, "Generic")
        }
        if gamepads.isConnected, let name = gamepads.name {
            return (name, gamepads.state, gamepads.battery, "Gamepad")
        }
        return nil
    }

    private func persist() {
        mapper.profile = profile
        try? ProfileStore.save(profile, to: storeURL)
    }
}
