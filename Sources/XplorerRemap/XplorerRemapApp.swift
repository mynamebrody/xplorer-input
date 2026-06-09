import SwiftUI

@main
struct XplorerRemapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("Xplorer Remap") {
            MainView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}
