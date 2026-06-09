import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pure-SPM executables launched via `swift run` have no bundle, so
        // AppKit treats them as background processes (no Dock icon/menu bar).
        // Forcing .regular fixes dev runs; the bundled .app is unaffected.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Defeat App Nap: input → key latency matters for a rhythm game.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Low-latency controller input remapping")

        // Sleep would strand held keys; release them and let the reader's
        // reconnect polling recover after wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                AppModel.shared.systemWillSleep()
            }
        }

        AppModel.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Quitting when the window closes avoids invisible stuck-key sources.
        true
    }
}
