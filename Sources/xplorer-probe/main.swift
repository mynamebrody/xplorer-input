import ApplicationServices
import CXplorerUSB
import Foundation
import XplorerKit

// xplorer-probe: M1 verification tool.
//   swift run xplorer-probe            dump raw reports + decoded diffs
//   swift run xplorer-probe --play     also post mapped CGEvents (M3 smoke test)

let vid: UInt16 = 0x1430
let pid: UInt16 = 0x4748
let playMode = CommandLine.arguments.contains("--play")

// Shared with the SIGINT handler.
final class ProbeSession {
    static let shared = ProbeSession()
    let lock = NSLock()
    var device: OpaquePointer?
    var shouldStop = false

    func stop() {
        lock.lock()
        shouldStop = true
        if let dev = device { xplorer_abort(dev) }
        lock.unlock()
    }
}

signal(SIGINT, SIG_IGN)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
sigintSource.setEventHandler {
    print("\nstopping…")
    ProbeSession.shared.stop()
}
sigintSource.resume()

var engine: MappingEngine?
if playMode {
    let trusted = AXIsProcessTrusted()
    print("play mode: posting CGEvents (Accessibility trusted: \(trusted))")
    if !trusted {
        print("⚠️  grant Accessibility to your terminal app in System Settings →")
        print("   Privacy & Security → Accessibility, then re-run.")
    }
    engine = MappingEngine(keyMap: .cloneHeroDefault, post: makeCGEventPoster())
}

func hex(_ bytes: ArraySlice<UInt8>) -> String {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

func describe(_ state: ControllerState) -> String {
    let pressed = GuitarControl.displayOrder
        .filter { state.pressed.contains($0) }
        .map(\.rawValue)
        .joined(separator: "+")
    return "[\(pressed.isEmpty ? "—" : pressed)] whammy(RX)=\(state.whammyRaw) tilt(RY)=\(state.tiltRaw)"
}

print("xplorer-probe: looking for Guitar Hero X-plorer (\(String(format: "%04x:%04x", vid, pid)))…")
print("press every fret, strum both ways, Start, Select, work the whammy, tilt the neck.")
print("Ctrl-C to stop.\n")

var lastReport: [UInt8] = []
var lastState: ControllerState?

while !ProbeSession.shared.shouldStop {
    var err: XplorerResult = XPLORER_OK
    guard let dev = xplorer_open(vid, pid, &err) else {
        if err == XPLORER_NOT_FOUND {
            print("waiting for device… (\(String(cString: xplorer_result_name(err.rawValue))))")
        } else {
            print("open failed: \(String(cString: xplorer_result_name(err.rawValue)))")
        }
        Thread.sleep(forTimeInterval: 1.0)
        continue
    }
    ProbeSession.shared.lock.lock()
    ProbeSession.shared.device = dev
    let stopping = ProbeSession.shared.shouldStop
    ProbeSession.shared.lock.unlock()
    if stopping {
        xplorer_close(dev)
        break
    }

    print("✅ connected — configuration set, interface claimed, reading reports\n")
    // Light LED 1 (player 1) as a connection nicety.
    var led: [UInt8] = [0x01, 0x03, 0x06]
    _ = xplorer_write(dev, &led, UInt32(led.count))

    var buffer = [UInt8](repeating: 0, count: 32)
    readLoop: while !ProbeSession.shared.shouldStop {
        let n = xplorer_read(dev, &buffer, UInt32(buffer.count))
        if n <= 0 {
            print("read ended: \(String(cString: xplorer_result_name(n)))")
            break readLoop // aborted → stop; disconnected/io error → reopen loop
        }
        let report = Array(buffer[0..<Int(n)])
        if report != lastReport {
            lastReport = report
            print("raw[\(n)]: \(hex(report[0..<Int(n)]))")
        }
        guard let state = ReportParser.parse(report) else {
            print("        (non-input message — ignored)")
            continue
        }
        if state != lastState {
            lastState = state
            print("        \(describe(state))")
            engine?.apply(state)
        }
    }

    engine?.releaseAll()
    ProbeSession.shared.lock.lock()
    ProbeSession.shared.device = nil
    ProbeSession.shared.lock.unlock()
    xplorer_close(dev)

    if !ProbeSession.shared.shouldStop {
        print("reconnecting…")
        Thread.sleep(forTimeInterval: 1.0)
    }
}

engine?.releaseAll()
print("bye")
