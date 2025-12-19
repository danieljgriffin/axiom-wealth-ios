import Foundation

enum TimeRange: String, CaseIterable, Identifiable, Codable {
    case h24 = "24H"
    case w1 = "1W"
    case m1 = "1M"
    case m3 = "3M"
    case m6 = "6M"
    case y1 = "1Y"
    case max = "MAX"
    
    var id: String { rawValue }
    
    var apiPeriod: String {
        switch self {
        case .h24: return "24H"
        case .w1: return "1W"
        case .m1: return "1M"
        case .m3: return "3M"
        case .m6: return "6M"
        case .y1: return "1Y"
        case .max: return "MAX"
        }
    }
}
