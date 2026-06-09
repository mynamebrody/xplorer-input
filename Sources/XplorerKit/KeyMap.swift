/// A guitar control bound to a macOS virtual key code.
public struct KeyBinding: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var label: String

    public init(keyCode: UInt16, label: String? = nil) {
        self.keyCode = keyCode
        self.label = label ?? KeyCodeLabels.label(for: keyCode)
    }
}

/// The full control → key mapping.
public struct KeyMap: Codable, Equatable, Sendable {
    public var bindings: [GuitarControl: KeyBinding]

    public init(bindings: [GuitarControl: KeyBinding]) {
        self.bindings = bindings
    }

    /// Clone Hero's default keyboard controls.
    /// Tilt shares H with Select — the engine refcounts shared keycodes.
    public static let cloneHeroDefault = KeyMap(bindings: [
        .green: KeyBinding(keyCode: 0),       // A
        .red: KeyBinding(keyCode: 1),         // S
        .yellow: KeyBinding(keyCode: 38),     // J
        .blue: KeyBinding(keyCode: 40),       // K
        .orange: KeyBinding(keyCode: 37),     // L
        .strumUp: KeyBinding(keyCode: 126),   // Up arrow
        .strumDown: KeyBinding(keyCode: 125), // Down arrow
        .start: KeyBinding(keyCode: 36),      // Return
        .select: KeyBinding(keyCode: 4),      // H
        .whammy: KeyBinding(keyCode: 41),     // ;
        .tilt: KeyBinding(keyCode: 4),        // H (Star Power via tilt)
    ])
}
