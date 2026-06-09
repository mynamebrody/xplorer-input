import SwiftUI
import XplorerKit

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView()
            Divider()
            VStack(spacing: 2) {
                ForEach(GuitarControl.displayOrder, id: \.self) { control in
                    MappingRowView(control: control)
                    if control != GuitarControl.displayOrder.last {
                        Divider().opacity(0.3)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            Divider()
            HStack {
                Text("Click a key to rebind it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to Clone Hero Defaults") {
                    model.resetToDefaults()
                }
            }
            .padding(12)
        }
        .frame(width: 440)
        .fixedSize()
        .onExitCommand { model.cancelRecording() }
    }
}
