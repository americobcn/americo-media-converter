import SwiftUI

struct ConversionTabsView: View {
    @Environment(ConverterViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 8) {
            ConversionTabBar(selection: $vm.selectedTab)

            Group {
                switch vm.selectedTab {
                case .audio:
                    AudioTabView()
                case .video:
                    VideoTabView()
                case .normalize:
                    NormalizeTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background.secondary, in: .rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.separator)
            }
        }
    }
}
