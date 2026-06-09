/// Axis calibration constants, verified empirically via `xplorer-probe`
/// against real hardware (2026-06-09).
public enum AxisCalibration {
    /// Whammy rides RX: rest = -32768 untouched, +32767 at full press.
    public static let whammyRest: Int16 = .min
    public static let whammyFull: Int16 = .max
    /// Tilt rides RY: idles ≈ +3000 (±300 jitter) held normally, +32767 with
    /// the neck vertical, negative when pointed down. Threshold at 0.5
    /// normalized (raw ≈ +16384) cleanly separates Star Power tilts.
    public static let tiltRest: Int16 = 0
    public static let tiltFull: Int16 = .max
}

/// A decoded snapshot of the guitar's state from one 20-byte input report.
public struct ControllerState: Equatable, Sendable {
    /// Digital controls currently held (frets, strum, start, select).
    public var pressed: Set<GuitarControl> = []
    public var whammyRaw: Int16 = AxisCalibration.whammyRest
    public var tiltRaw: Int16 = AxisCalibration.tiltRest

    public init() {}

    /// Whammy travel normalized to 0...1.
    public var whammyNormalized: Double {
        Self.normalize(whammyRaw, rest: AxisCalibration.whammyRest, full: AxisCalibration.whammyFull)
    }

    /// Tilt normalized to 0...1.
    public var tiltNormalized: Double {
        Self.normalize(tiltRaw, rest: AxisCalibration.tiltRest, full: AxisCalibration.tiltFull)
    }

    static func normalize(_ raw: Int16, rest: Int16, full: Int16) -> Double {
        let span = Double(full) - Double(rest)
        guard span != 0 else { return 0 }
        let value = (Double(raw) - Double(rest)) / span
        return min(max(value, 0), 1)
    }
}
