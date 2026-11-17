import SwiftUI

struct AC3ButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.custom("Helvetica Neue", size: 16))
            .foregroundStyle(Color(nsColor: .lightGray))
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(isHovering && isEnabled ? Color(nsColor: .systemIndigo) : Color(nsColor: .darkGray))
            .clipShape(.rect(cornerRadius: 2))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5)
            .contentShape(.rect)
            .onHover { isHovering = $0 }
    }
}
