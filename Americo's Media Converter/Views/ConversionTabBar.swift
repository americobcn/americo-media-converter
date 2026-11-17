import SwiftUI

struct ConversionTabBar: View {
    @Binding var selection: ConversionTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ConversionTab.allCases) { tab in
                Button {
                    select(tab)
                } label: {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .foregroundStyle(selection == tab ? Color.white : Color.primary)
                        .background(selection == tab ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 5))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.quaternary, in: .rect(cornerRadius: 7))
    }

    private func select(_ tab: ConversionTab) {
        selection = tab
    }
}
