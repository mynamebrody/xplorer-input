/// Every mappable control on the Guitar Hero X-plorer.
public enum GuitarControl: String, Codable, CaseIterable, Hashable, Sendable {
    case green
    case red
    case yellow
    case blue
    case orange
    case strumUp
    case strumDown
    case start
    case select
    case whammy
    case tilt

    /// UI display order (matches the Clone Hero default-controls table).
    public static let displayOrder: [GuitarControl] = [
        .green, .red, .yellow, .blue, .orange,
        .strumUp, .strumDown, .start, .select, .whammy, .tilt,
    ]

    public var displayName: String {
        switch self {
        case .green: return "Green"
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .blue: return "Blue"
        case .orange: return "Orange"
        case .strumUp: return "Strum Up"
        case .strumDown: return "Strum Down"
        case .start: return "Start/Pause"
        case .select: return "Select/Star Power"
        case .whammy: return "Whammy"
        case .tilt: return "Tilt"
        }
    }

    /// Analog controls are driven by axis thresholds, not button bits.
    public var isAnalog: Bool {
        self == .whammy || self == .tilt
    }
}
