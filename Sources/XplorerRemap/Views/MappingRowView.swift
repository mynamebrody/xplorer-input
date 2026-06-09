import SwiftUI
import XplorerKit

struct MappingRowView: View {
    @EnvironmentObject private var model: AppModel
    let control: GuitarControl

    private var isRecording: Bool { model.recordingControl == control }

    private var isActive: Bool {
        if control == .whammy { return model.liveState.whammyNormalized > MappingEngine.analogOn }
        if control == .tilt { return model.liveState.tiltNormalized > MappingEngine.analogOn }
        return model.liveState.pressed.contains(control)
    }

    var body: some View {
        HStack(spacing: 10) {
            indicator
                .frame(width: 70, alignment: .leading)
            Text(control.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: toggleRecording) {
                Text(isRecording ? "Press a key… (Esc cancels)" : keyLabel)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: isRecording ? 180 : 90)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
        }
        .padding(.vertical, 4)
    }

    private var keyLabel: String {
        model.keyMap.bindings[control]?.label ?? "—"
    }

    @ViewBuilder
    private var indicator: some View {
        if control.isAnalog {
            AnalogBarView(
                value: control == .whammy
                    ? model.liveState.whammyNormalized
                    : model.liveState.tiltNormalized,
                active: isActive
            )
        } else {
            Circle()
                .fill(isActive ? fretColor : Color.secondary.opacity(0.25))
                .frame(width: 14, height: 14)
                .animation(.linear(duration: 0.05), value: isActive)
        }
    }

    private var fretColor: Color {
        switch control {
        case .green: return .green
        case .red: return .red
        case .yellow: return .yellow
        case .blue: return .blue
        case .orange: return .orange
        default: return .accentColor
        }
    }

    private func toggleRecording() {
        if isRecording {
            model.cancelRecording()
        } else {
            model.beginRecording(control)
        }
    }
}
