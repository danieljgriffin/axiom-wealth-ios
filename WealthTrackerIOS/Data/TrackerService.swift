import Foundation

struct TrackerSnapshot: Codable, Identifiable {
    let year: Int
    let month: String
    let totalNetWorth: Double
    private let savedPlatformBreakdown: [String: Double]?

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var id: String { "\(year)-\(month)" }
    var monthNumber: Int {
        Self.months.firstIndex(of: String(month.suffix(3))).map { $0 + 1 } ?? 0
    }
    var displayDate: String { "1 \(month.suffix(3))" }
    var platformBreakdown: [String: Double] { savedPlatformBreakdown ?? [:] }

    enum CodingKeys: String, CodingKey {
        case year, month
        case totalNetWorth = "total_networth"
        case savedPlatformBreakdown = "platform_breakdown"
    }
}

struct TrackerEntryRequest: Encodable {
    let entry_key: String
    let income_amount: Double
    let income_date: String?
    let investment_amount: Double
    let investment_date: String?
    let destination_platform: String?
    let note: String?
}

struct TrackerMovementRequest: Encodable {
    let event_key: String
    let flow_type: String
    let amount: Double
    let effective_date: String
    let source_platform: String
    let destination_platform: String?
    let note: String?
}

enum TrackerSubmission {
    case entry(TrackerEntryRequest)
    case movement(TrackerMovementRequest)
}

enum TrackerService {
    private struct SavedActivity: Codable {
        let id: Int
    }

    static func snapshots() async throws -> [TrackerSnapshot] {
        try await APIClient.shared.fetch("/net-worth/monthly-tracker")
    }

    static func incomeTotals() async throws -> [APIIncomeData] {
        try await APIClient.shared.fetch("/cashflow/income")
    }

    static func netWorth() async throws -> APINetWorthSummary {
        try await APIClient.shared.fetch("/net-worth/summary")
    }

    static func save(_ submission: TrackerSubmission) async throws {
        switch submission {
        case .entry(let entry):
            let _: SavedActivity = try await APIClient.shared.send("/cashflow/tracker-entries", body: entry)
        case .movement(let movement):
            let _: SavedActivity = try await APIClient.shared.send("/cashflow/movements", body: movement)
        }
    }

    static func updateTotals(year: Int, income: Double, investment: Double) async throws {
        var endpoint = URLComponents()
        endpoint.path = "/cashflow/income"
        endpoint.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "income", value: String(income)),
            URLQueryItem(name: "investment", value: String(investment))
        ]
        let today = Date()
        if year == calendar.component(.year, from: today) {
            endpoint.queryItems?.append(URLQueryItem(name: "effective_date", value: dateString(today)))
        }
        guard let path = endpoint.string else { throw APIError.invalidURL(endpoint.path) }
        let _: APIIncomeData = try await APIClient.shared.send(path, body: Optional<String>.none)
    }

    static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
