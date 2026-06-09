/// Decodes wired Xbox 360 XInput input reports into `ControllerState`.
///
/// Report layout (20 bytes, interrupt IN):
///   byte 0: message type (0x00 = input; 0x01 = LED status — ignored)
///   byte 1: length (0x14)
///   byte 2: bit0 DpadUp(StrumUp) bit1 DpadDown(StrumDown) bit2 DpadLeft
///           bit3 DpadRight bit4 Start bit5 Back(Select) bit6 L3 bit7 R3
///   byte 3: bit0 LB(Orange) bit1 RB bit2 Guide bit4 A(Green) bit5 B(Red)
///           bit6 X(Blue) bit7 Y(Yellow)
///   bytes 4-5: triggers; 6-7 LX; 8-9 LY; 10-11 RX (Whammy); 12-13 RY (Tilt)
public enum ReportParser {
    public static let reportLength = 20

    public static func parse(_ report: [UInt8]) -> ControllerState? {
        guard report.count >= reportLength,
              report[0] == 0x00,
              report[1] == 0x14
        else { return nil }

        var state = ControllerState()
        let buttonsLow = report[2]
        let buttonsHigh = report[3]

        if buttonsLow & 0x01 != 0 { state.pressed.insert(.strumUp) }
        if buttonsLow & 0x02 != 0 { state.pressed.insert(.strumDown) }
        if buttonsLow & 0x10 != 0 { state.pressed.insert(.start) }
        if buttonsLow & 0x20 != 0 { state.pressed.insert(.select) }

        if buttonsHigh & 0x01 != 0 { state.pressed.insert(.orange) } // LB
        if buttonsHigh & 0x10 != 0 { state.pressed.insert(.green) }  // A
        if buttonsHigh & 0x20 != 0 { state.pressed.insert(.red) }    // B
        if buttonsHigh & 0x40 != 0 { state.pressed.insert(.blue) }   // X
        if buttonsHigh & 0x80 != 0 { state.pressed.insert(.yellow) } // Y

        state.whammyRaw = int16le(report, at: 10)
        state.tiltRaw = int16le(report, at: 12)
        return state
    }

    static func int16le(_ bytes: [UInt8], at index: Int) -> Int16 {
        Int16(bitPattern: UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
    }
}
