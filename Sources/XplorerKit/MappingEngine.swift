import Foundation

/// Diffs successive `ControllerState`s and emits keyDown/keyUp events via the
/// injected `post` closure (production: CGEventPost; tests: a recorder).
///
/// - Per-keycode refcounting: two controls may share one key (Tilt + Select
///   both default to H) — keyDown fires on 0→1, keyUp on 1→0.
/// - Analog hysteresis: whammy/tilt become "active" above `analogOn` and
///   release below `analogOff`, so axis noise never chatters keys.
/// - Edge transitions only: no autorepeat synthesis (games don't want it).
///
/// Thread-safe: `apply` runs on the USB reader thread; everything else may be
/// called from the main thread.
public final class MappingEngine {
    public static let analogOn = 0.50
    public static let analogOff = 0.40

    private let lock = NSLock()
    private var keyMap: KeyMap
    private let post: (UInt16, Bool) -> Void
    private var heldCounts: [UInt16: Int] = [:]
    private var previousActive: Set<GuitarControl> = []
    private var whammyEngaged = false
    private var tiltEngaged = false
    private var suspended = false

    public init(keyMap: KeyMap, post: @escaping (UInt16, Bool) -> Void) {
        self.keyMap = keyMap
        self.post = post
    }

    /// Apply a new controller snapshot, emitting key transitions.
    public func apply(_ state: ControllerState) {
        lock.lock()
        defer { lock.unlock() }
        guard !suspended else { return }

        if whammyEngaged {
            whammyEngaged = state.whammyNormalized >= Self.analogOff
        } else {
            whammyEngaged = state.whammyNormalized > Self.analogOn
        }
        if tiltEngaged {
            tiltEngaged = state.tiltNormalized >= Self.analogOff
        } else {
            tiltEngaged = state.tiltNormalized > Self.analogOn
        }

        var active = state.pressed
        if whammyEngaged { active.insert(.whammy) }
        if tiltEngaged { active.insert(.tilt) }

        for control in active.subtracting(previousActive) { pressLocked(control) }
        for control in previousActive.subtracting(active) { releaseLocked(control) }
        previousActive = active
    }

    /// Replace the key map. Releases all held keys first so a rebind can
    /// never leave a key stuck under its old code.
    public func updateKeyMap(_ newMap: KeyMap) {
        lock.lock()
        defer { lock.unlock() }
        releaseAllLocked()
        keyMap = newMap
    }

    /// While suspended (key-recording mode), guitar input posts nothing —
    /// otherwise the recorder would capture the guitar's own synthesized keys.
    public func setSuspended(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if value && !suspended { releaseAllLocked() }
        suspended = value
    }

    /// Release every held key. Called on disconnect, sleep, quit, suspend.
    public func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        releaseAllLocked()
    }

    // MARK: - Locked internals

    private func pressLocked(_ control: GuitarControl) {
        guard let binding = keyMap.bindings[control] else { return }
        let count = (heldCounts[binding.keyCode] ?? 0) + 1
        heldCounts[binding.keyCode] = count
        if count == 1 { post(binding.keyCode, true) }
    }

    private func releaseLocked(_ control: GuitarControl) {
        guard let binding = keyMap.bindings[control] else { return }
        let count = (heldCounts[binding.keyCode] ?? 0) - 1
        if count <= 0 {
            heldCounts.removeValue(forKey: binding.keyCode)
            post(binding.keyCode, false)
        } else {
            heldCounts[binding.keyCode] = count
        }
    }

    private func releaseAllLocked() {
        for keyCode in heldCounts.keys { post(keyCode, false) }
        heldCounts.removeAll()
        previousActive.removeAll()
        whammyEngaged = false
        tiltEngaged = false
    }
}
