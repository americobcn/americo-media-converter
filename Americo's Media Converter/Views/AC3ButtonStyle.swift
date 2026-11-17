import SwiftUI

struct AC3ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AC3ButtonBody(configuration: configuration)
    }
}
