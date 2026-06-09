import AppKit

/// Captures the next keypress while the app window is key, via a local
/// NSEvent monitor (no permissions required). Escape cancels.
final class KeyRecorder {
    private var monitor: Any?

    /// `onKey` receives the captured key code, or nil if cancelled (Esc).
    func start(onKey: @escaping (UInt16?) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.stop()
            onKey(event.keyCode == 53 ? nil : event.keyCode) // 53 = Esc
            return nil // swallow the event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
