import SwiftUI

enum LogKind: CaseIterable, Identifiable {
    case regular, error, success

    var id: Self { return self }

    var color: Color {
        switch self {
        case .regular: return Color(nsColor: .lightGray)
        case .error: return .red
        case .success: return .green
        }
    }
}
