import SwiftUI

struct LogView: View {
    @Environment(ConverterViewModel.self) private var vm
    let tab: ConversionTab

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(vm.log(for: tab)) { entry in
                    Text(entry.displayText)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.kind.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .textSelection(.enabled)
            .padding(5)
        }
        .defaultScrollAnchor(.bottom)
        .background(.black)
    }
}
