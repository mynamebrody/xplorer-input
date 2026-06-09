import SwiftUI

/// Horizontal fill bar for whammy/tilt travel (0...1).
struct AnalogBarView: View {
    let value: Double
    let active: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: 3)
                    .fill(active ? Color.accentColor : Color.secondary.opacity(0.6))
                    .frame(width: max(2, proxy.size.width * value))
            }
        }
        .frame(width: 70, height: 8)
        .animation(.linear(duration: 0.05), value: value)
    }
}
