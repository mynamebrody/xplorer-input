import CXplorerUSB
import Foundation
import XplorerKit

enum ConnectionStatus: Equatable {
    case searching
    case connected
    case busy // another process holds exclusive access

    var label: String {
        switch self {
        case .searching: return "Searching for Guitar Hero X-plorer…"
        case .connected: return "Guitar Hero X-plorer — Connected"
        case .busy: return "Guitar found, but another app is using it"
        }
    }
}

/// Owns the background USB reader thread.
///
/// Outer loop: try `xplorer_open` once per second (this *is* the arrival,
/// replug, and wake-recovery polling). Inner loop: blocking reads → engine on
/// this thread (no main-thread hop before CGEventPost), throttled state
/// publishes to the UI.
final class ControllerReader {
    private static let vid: UInt16 = 0x1430
    private static let pid: UInt16 = 0x4748
    private static let uiPublishInterval: TimeInterval = 1.0 / 30.0

    private let engine: MappingEngine
    private let lock = NSLock()
    private var device: OpaquePointer?
    private var stopped = false
    private var thread: Thread?

    /// Called on the main queue.
    var onStatus: ((ConnectionStatus) -> Void)?
    var onState: ((ControllerState) -> Void)?

    init(engine: MappingEngine) {
        self.engine = engine
    }

    func start() {
        guard thread == nil else { return }
        let thread = Thread { [weak self] in self?.run() }
        thread.name = "xplorer-usb-reader"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
    }

    func stop() {
        lock.lock()
        stopped = true
        if let dev = device { xplorer_abort(dev) }
        lock.unlock()
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func publish(_ status: ConnectionStatus) {
        DispatchQueue.main.async { [weak self] in self?.onStatus?(status) }
    }

    private func run() {
        var lastPublish = Date.distantPast
        var lastPublishedState: ControllerState?

        while !isStopped {
            var err: XplorerResult = XPLORER_OK
            guard let dev = xplorer_open(Self.vid, Self.pid, &err) else {
                publish(err == XPLORER_BUSY ? .busy : .searching)
                Thread.sleep(forTimeInterval: 1.0)
                continue
            }

            lock.lock()
            device = dev
            let alreadyStopped = stopped
            lock.unlock()
            if alreadyStopped {
                xplorer_close(dev)
                break
            }

            publish(.connected)
            var led: [UInt8] = [0x01, 0x03, 0x06] // player-1 LED
            _ = xplorer_write(dev, &led, UInt32(led.count))

            var buffer = [UInt8](repeating: 0, count: 32)
            while !isStopped {
                let n = xplorer_read(dev, &buffer, UInt32(buffer.count))
                if n <= 0 { break } // aborted, disconnected, or io error
                guard let state = ReportParser.parse(Array(buffer[0..<Int(n)])) else {
                    continue // LED status / non-input message
                }
                engine.apply(state)

                // Digital changes publish immediately; analog-only wiggle is
                // throttled to ~30 Hz so the whammy can't flood SwiftUI.
                let now = Date()
                let digitalChanged = state.pressed != lastPublishedState?.pressed
                if digitalChanged || now.timeIntervalSince(lastPublish) >= Self.uiPublishInterval {
                    lastPublish = now
                    lastPublishedState = state
                    DispatchQueue.main.async { [weak self] in self?.onState?(state) }
                }
            }

            engine.releaseAll()
            lock.lock()
            device = nil
            lock.unlock()
            xplorer_close(dev)

            if !isStopped {
                publish(.searching)
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
}
