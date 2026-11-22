import XCTest
@testable import YokeCore

final class MapperTests: XCTestCase {
    func testDeadzoneDropsNoise() {
        let velocity = StickMath.mouseVelocity(
            stick: Stick(x: 0.05, y: 0.05),
            feel: .bed,
            precision: false
        )
        XCTAssertEqual(velocity, .zero)
    }

    func testFullDeflectionReachesMaxSpeedAndFlipsY() {
        let velocity = StickMath.mouseVelocity(
            stick: Stick(x: 0, y: 1),
            feel: .bed,
            precision: false
        )
        XCTAssertEqual(velocity.x, 0, accuracy: 0.001)
        XCTAssertEqual(velocity.y, -Feel.bed.maxSpeed, accuracy: 0.001)
    }

    func testPrecisionSlowsThePointer() {
        let full = StickMath.mouseVelocity(stick: Stick(x: 1, y: 0), feel: .bed, precision: false)
        let slow = StickMath.mouseVelocity(stick: Stick(x: 1, y: 0), feel: .bed, precision: true)
        XCTAssertEqual(slow.x, full.x * Feel.bed.precisionScale, accuracy: 0.001)
    }

    func testDictateHoldsTheConfiguredComboAndReleases() {
        var mapper = Mapper()
        var pad = PadState()
        pad.amount[.rightBumper] = 1
        let held = mapper.step(pad, dt: 1.0 / 120)
        XCTAssertEqual(held.heldKeys, [.function])
        XCTAssertTrue(held.tappedKeys.isEmpty)

        var released = mapper.step(PadState(), dt: 1.0 / 120)
        XCTAssertEqual(released.heldKeys, [.function])
        for _ in 0..<4 { released = mapper.step(PadState(), dt: 1.0 / 120) }
        XCTAssertTrue(released.heldKeys.isEmpty)
    }

    func testTapFiresOnce() {
        var mapper = Mapper()
        var pad = PadState()
        pad.amount[.dpadRight] = 1
        XCTAssertEqual(mapper.step(pad, dt: 0.01).tappedKeys, [.nextSpace])
        XCTAssertTrue(mapper.step(pad, dt: 0.01).tappedKeys.isEmpty)
    }

    func testClickStaysDownWhileHeld() {
        var mapper = Mapper()
        var pad = PadState()
        pad.amount[.south] = 1
        XCTAssertEqual(mapper.step(pad, dt: 0.01).clicks, [.left])
        XCTAssertEqual(mapper.step(pad, dt: 0.01).clicks, [.left])
        var released = mapper.step(PadState(), dt: 0.01)
        XCTAssertEqual(released.clicks, [.left])
        for _ in 0..<4 { released = mapper.step(PadState(), dt: 0.01) }
        XCTAssertTrue(released.clicks.isEmpty)
    }

    func testStartSuspendsAndResumesWithoutAStuckKey() {
        var mapper = Mapper()
        var talking = PadState()
        talking.amount[.rightBumper] = 1
        talking.amount[.menu] = 1
        let suspended = mapper.step(talking, dt: 0.01)
        XCTAssertTrue(suspended.suspended)
        XCTAssertTrue(suspended.heldKeys.isEmpty)

        var stillHeld = PadState()
        stillHeld.amount[.rightBumper] = 1
        for _ in 0..<5 {
            XCTAssertTrue(mapper.step(stillHeld, dt: 0.01).suspended)
        }
        stillHeld.amount[.menu] = 1
        let resumed = mapper.step(stillHeld, dt: 0.01)
        XCTAssertFalse(resumed.suspended)
        XCTAssertEqual(resumed.heldKeys, [.function])
    }

    func testHitchDoesNotFlingThePointer() {
        var mapper = Mapper()
        var pad = PadState()
        pad.left = Stick(x: 1, y: 0)
        let frame = mapper.step(pad, dt: 2)
        XCTAssertLessThanOrEqual(frame.mouseX, Feel.bed.maxSpeed * 0.05 + 0.001)
    }

    func testProfileRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yoke-profile-\(UUID().uuidString).json")
        var profile = Profile.bed
        profile.feel.maxSpeed = 2200
        profile.hidButtons[4] = .north
        try ProfileStore.save(profile, to: url)
        let loaded = ProfileStore.load(from: url)
        XCTAssertEqual(loaded, profile)
    }

    func testMissingProfileFallsBackToBed() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).json")
        XCTAssertEqual(ProfileStore.load(from: url).dictation, .function)
    }
}
