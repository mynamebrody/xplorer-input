import XCTest
@testable import XplorerKit

final class MappingEngineTests: XCTestCase {
    private var posted: [(keyCode: UInt16, down: Bool)] = []
    private var engine: MappingEngine!

    override func setUp() {
        super.setUp()
        posted = []
        engine = MappingEngine(keyMap: .cloneHeroDefault) { [weak self] code, down in
            self?.posted.append((code, down))
        }
    }

    private func state(
        _ pressed: Set<GuitarControl> = [],
        whammy: Double = 0,
        tilt: Double = 0
    ) -> ControllerState {
        var s = ControllerState()
        s.pressed = pressed
        s.whammyRaw = rawAxis(whammy, rest: AxisCalibration.whammyRest, full: AxisCalibration.whammyFull)
        s.tiltRaw = rawAxis(tilt, rest: AxisCalibration.tiltRest, full: AxisCalibration.tiltFull)
        return s
    }

    private func rawAxis(_ normalized: Double, rest: Int16, full: Int16) -> Int16 {
        let span = Double(full) - Double(rest)
        return Int16(clamping: Int(Double(rest) + normalized * span))
    }

    func testPressAndRelease() {
        engine.apply(state([.green]))
        engine.apply(state([]))
        XCTAssertEqual(posted.count, 2)
        XCTAssertEqual(posted[0].keyCode, 0) // A
        XCTAssertTrue(posted[0].down)
        XCTAssertEqual(posted[1].keyCode, 0)
        XCTAssertFalse(posted[1].down)
    }

    func testNoRepeatWhileHeld() {
        engine.apply(state([.green]))
        engine.apply(state([.green]))
        engine.apply(state([.green]))
        XCTAssertEqual(posted.count, 1)
    }

    func testChordTransitions() {
        engine.apply(state([.green, .strumDown]))
        XCTAssertEqual(Set(posted.map(\.keyCode)), [0, 125]) // A + Down
        XCTAssertTrue(posted.allSatisfy(\.down))
        posted = []
        engine.apply(state([.green])) // strum released, fret held
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(posted[0].keyCode, 125)
        XCTAssertFalse(posted[0].down)
    }

    func testWhammyHysteresisNoChatter() {
        engine.apply(state(whammy: 0.45)) // below on-threshold: nothing
        XCTAssertTrue(posted.isEmpty)
        engine.apply(state(whammy: 0.60)) // engage
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(posted[0].keyCode, 41) // ;
        engine.apply(state(whammy: 0.45)) // inside hysteresis band: stays held
        engine.apply(state(whammy: 0.55))
        engine.apply(state(whammy: 0.42))
        XCTAssertEqual(posted.count, 1)
        engine.apply(state(whammy: 0.10)) // below off-threshold: release
        XCTAssertEqual(posted.count, 2)
        XCTAssertFalse(posted[1].down)
    }

    func testSharedKeycodeRefcounting() {
        // Select and Tilt both map to H (keycode 4): one keyDown, and keyUp
        // only after BOTH release.
        engine.apply(state([.select], tilt: 0.9))
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(posted[0].keyCode, 4)
        engine.apply(state([], tilt: 0.9)) // select released, tilt still active
        XCTAssertEqual(posted.count, 1, "H must stay held while tilt is active")
        engine.apply(state([], tilt: 0.0)) // both released
        XCTAssertEqual(posted.count, 2)
        XCTAssertFalse(posted[1].down)
    }

    func testReleaseAll() {
        engine.apply(state([.green, .red, .strumUp]))
        posted = []
        engine.releaseAll()
        XCTAssertEqual(posted.count, 3)
        XCTAssertTrue(posted.allSatisfy { !$0.down })
        // After releaseAll, re-pressing posts fresh downs.
        engine.apply(state([.green]))
        XCTAssertEqual(posted.last?.down, true)
    }

    func testSuspendReleasesAndMutes() {
        engine.apply(state([.green]))
        posted = []
        engine.setSuspended(true)
        XCTAssertEqual(posted.count, 1) // green released
        XCTAssertFalse(posted[0].down)
        engine.apply(state([.red])) // muted while suspended
        XCTAssertEqual(posted.count, 1)
        engine.setSuspended(false)
        engine.apply(state([.red]))
        XCTAssertEqual(posted.count, 2)
        XCTAssertTrue(posted[1].down)
    }

    func testRebindReleasesHeldKeys() {
        engine.apply(state([.green]))
        posted = []
        var newMap = KeyMap.cloneHeroDefault
        newMap.bindings[.green] = KeyBinding(keyCode: 12) // Q
        engine.updateKeyMap(newMap)
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(posted[0].keyCode, 0) // old A released
        XCTAssertFalse(posted[0].down)
        engine.apply(state([.green]))
        XCTAssertEqual(posted.last?.keyCode, 12)
    }

    func testUnmappedControlIsIgnored() {
        var map = KeyMap.cloneHeroDefault
        map.bindings.removeValue(forKey: .tilt)
        engine.updateKeyMap(map)
        engine.apply(state(tilt: 0.9))
        XCTAssertTrue(posted.isEmpty)
    }
}
