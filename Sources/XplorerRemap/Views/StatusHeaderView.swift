import SwiftUI
import XplorerKit

struct StatusHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(model.connection.label)
                    .font(.headline)
                Spacer()
            }
            if !model.axTrusted {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Accessibility permission needed to send key presses")
                        .font(.caption)
                    Spacer()
                    Button("Open Settings") {
                        AccessibilityGate.openSettings()
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
    }

    private var statusColor: Color {
        switch model.connection {
        case .connected: return .green
        case .busy: return .orange
        case .searching: return .red
        }
    }
}
