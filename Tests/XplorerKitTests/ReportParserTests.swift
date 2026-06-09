import XCTest
@testable import XplorerKit

final class ReportParserTests: XCTestCase {
    /// Build a 20-byte wired-360 input report.
    private func report(
        b2: UInt8 = 0, b3: UInt8 = 0,
        whammy: Int16 = AxisCalibration.whammyRest,
        tilt: Int16 = AxisCalibration.tiltRest
    ) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x00
        bytes[1] = 0x14
        bytes[2] = b2
        bytes[3] = b3
        let w = UInt16(bitPattern: whammy)
        bytes[10] = UInt8(w & 0xFF)
        bytes[11] = UInt8(w >> 8)
        let t = UInt16(bitPattern: tilt)
        bytes[12] = UInt8(t & 0xFF)
        bytes[13] = UInt8(t >> 8)
        return bytes
    }

    func testRejectsNonInputMessages() {
        // LED status message (type 0x01)
        var led = [UInt8](repeating: 0, count: 20)
        led[0] = 0x01
        led[1] = 0x03
        XCTAssertNil(ReportParser.parse(led))
        // Truncated report
        XCTAssertNil(ReportParser.parse([0x00, 0x14, 0x00]))
        // Wrong length byte
        var wrong = report()
        wrong[1] = 0x03
        XCTAssertNil(ReportParser.parse(wrong))
    }

    func testIdleReportParsesEmpty() {
        let state = ReportParser.parse(report())
        XCTAssertEqual(state?.pressed, [])
    }

    func testFretButtons() {
        XCTAssertEqual(ReportParser.parse(report(b3: 0x10))?.pressed, [.green])
        XCTAssertEqual(ReportParser.parse(report(b3: 0x20))?.pressed, [.red])
        XCTAssertEqual(ReportParser.parse(report(b3: 0x80))?.pressed, [.yellow])
        XCTAssertEqual(ReportParser.parse(report(b3: 0x40))?.pressed, [.blue])
        XCTAssertEqual(ReportParser.parse(report(b3: 0x01))?.pressed, [.orange])
    }

    func testStrumStartSelect() {
        XCTAssertEqual(ReportParser.parse(report(b2: 0x01))?.pressed, [.strumUp])
        XCTAssertEqual(ReportParser.parse(report(b2: 0x02))?.pressed, [.strumDown])
        XCTAssertEqual(ReportParser.parse(report(b2: 0x10))?.pressed, [.start])
        XCTAssertEqual(ReportParser.parse(report(b2: 0x20))?.pressed, [.select])
    }

    func testChord() {
        let state = ReportParser.parse(report(b2: 0x02, b3: 0x30))
        XCTAssertEqual(state?.pressed, [.green, .red, .strumDown])
    }

    func testAxes() {
        let state = ReportParser.parse(report(whammy: 1234, tilt: -5678))
        XCTAssertEqual(state?.whammyRaw, 1234)
        XCTAssertEqual(state?.tiltRaw, -5678)
    }

    func testWhammyNormalization() {
        var state = ControllerState()
        state.whammyRaw = AxisCalibration.whammyRest
        XCTAssertEqual(state.whammyNormalized, 0, accuracy: 0.001)
        state.whammyRaw = AxisCalibration.whammyFull
        XCTAssertEqual(state.whammyNormalized, 1, accuracy: 0.001)
    }
}
