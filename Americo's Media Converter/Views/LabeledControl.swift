import SwiftUI

struct LabeledControl<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            content
                .labelsHidden()
        }
    }
}
