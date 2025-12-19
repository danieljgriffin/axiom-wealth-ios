import Foundation

struct NetWorthSummary: Codable {
    let currentNetWorth: Double
    let lastUpdated: Date
    let monthChange: Double
    let monthChangePercent: Double
    let yearChange: Double
    let yearChangePercent: Double
}

struct NetWorthPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case value
    }
}

struct PerformanceSeries: Codable {
    let h24: [NetWorthPoint]
    let w1: [NetWorthPoint]
    let m1: [NetWorthPoint]
    let m3: [NetWorthPoint]
    let m6: [NetWorthPoint]
    let y1: [NetWorthPoint]
    let max: [NetWorthPoint]
    
    func points(for range: TimeRange) -> [NetWorthPoint] {
        switch range {
        case .h24: return h24
        case .w1: return w1
        case .m1: return m1
        case .m3: return m3
        case .m6: return m6
        case .y1: return y1
        case .max: return max
        }
    }
}

struct PlatformBreakdownItem: Identifiable, Codable {
    var id: String { platform }
    let platform: String
    let value: Double
    let percentage: Double
    let monthChange: Double
    let monthChangePercent: Double
}
