import Foundation

enum LUFSTarget: Int, CaseIterable, Identifiable {
    case ebuR128 = -23
    case streaming16 = -16
    case streaming14 = -14
    case loud12 = -12
    case atsc85 = -24

    var id: Self { return self }

    var value: Int { rawValue }

    var title: String {
        switch self {
        case .ebuR128: return "-23 LUFS (EBU R128)"
        case .streaming16: return "-16 LUFSs"
        case .streaming14: return "-14 LUFS"
        case .loud12: return "-12 LUFS"
        case .atsc85: return "-24 LKFS(ATSC 85/A)"
        }
    }
}
