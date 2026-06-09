import CoreGraphics

/// Production key poster: synthesizes keyboard events at the HID event tap.
/// Requires the Accessibility TCC grant (no Apple Developer account needed).
public func makeCGEventPoster() -> (UInt16, Bool) -> Void {
    { keyCode, isDown in
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode),
            keyDown: isDown
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
