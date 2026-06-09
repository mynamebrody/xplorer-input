import AppKit
import Combine
import XplorerKit

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var connection: ConnectionStatus = .searching
    @Published var liveState = ControllerState()
    @Published var keyMap: KeyMap
    @Published var recordingControl: GuitarControl?
    @Published var axTrusted = false

    let engine: MappingEngine
    private let store = KeyMapStore()
    private var reader: ControllerReader?
    private let keyRecorder = KeyRecorder()
    private var trustTimer: Timer?

    private init() {
        let map = store.load()
        keyMap = map
        engine = MappingEngine(keyMap: map, post: makeCGEventPoster())
    }

    func start() {
        axTrusted = AccessibilityGate.isTrusted(prompting: true)
        scheduleTrustRecheck()

        let reader = ControllerReader(engine: engine)
        reader.onStatus = { [weak self] status in self?.connection = status }
        reader.onState = { [weak self] state in self?.liveState = state }
        self.reader = reader
        reader.start()
    }

    func shutdown() {
        cancelRecording()
        reader?.stop()
        engine.releaseAll()
    }

    func systemWillSleep() {
        engine.releaseAll()
    }

    // MARK: - Remapping

    func beginRecording(_ control: GuitarControl) {
        cancelRecording()
        recordingControl = control
        engine.setSuspended(true) // guitar input must not record itself
        keyRecorder.start { [weak self] keyCode in
            guard let self else { return }
            if let keyCode {
                self.setBinding(keyCode, for: control)
            }
            self.recordingControl = nil
            self.engine.setSuspended(false)
        }
    }

    func cancelRecording() {
        guard recordingControl != nil else { return }
        keyRecorder.stop()
        recordingControl = nil
        engine.setSuspended(false)
    }

    private func setBinding(_ keyCode: UInt16, for control: GuitarControl) {
        keyMap.bindings[control] = KeyBinding(keyCode: keyCode)
        engine.updateKeyMap(keyMap)
        store.save(keyMap)
    }

    func resetToDefaults() {
        cancelRecording()
        keyMap = store.reset()
        engine.updateKeyMap(keyMap)
    }

    // MARK: - Accessibility

    private func scheduleTrustRecheck() {
        guard !axTrusted else { return }
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                let trusted = AccessibilityGate.isTrusted(prompting: false)
                AppModel.shared.axTrusted = trusted
                if trusted {
                    AppModel.shared.trustTimer?.invalidate()
                    AppModel.shared.trustTimer = nil
                }
            }
        }
    }
}
