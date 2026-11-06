import Foundation

struct FinancePlan: Codable {
    struct Bill: Codable {
        enum Frequency: String, CaseIterable, Codable {
            case monthly, annual

            var title: String { self == .monthly ? "Monthly" : "Yearly" }
        }

        let name: String
        let amount_pence: Int
        let frequency: Frequency

        var annualPence: Int { amount_pence * (frequency == .monthly ? 12 : 1) }
    }

    struct Fund: Codable {
        let name: String
        let amount_pence: Int
        let instrument: PlanInstrument?
    }

    struct Allocation: Codable, Identifiable {
        let platform: String
        let amount_pence: Int
        let funds: [Fund]

        var id: String { platform }
        var unallocatedPence: Int { amount_pence - funds.reduce(0) { $0 + $1.amount_pence } }
        var displayOrder: Int {
            if platform.range(of: #"\b(crypto|coinbase|bitcoin)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                return 2
            }
            return platform.range(of: #"\bL?ISA\b"#, options: [.regularExpression, .caseInsensitive]) != nil ? 0 : 1
        }
    }

    var take_home_monthly_pence = 0
    var bills: [Bill] = []
    var allocations: [Allocation] = []

    var annualPay: Int { take_home_monthly_pence * 12 }
    var annualBills: Int { bills.reduce(0) { $0 + $1.annualPence } }
    var monthlyInvestments: Int { allocations.reduce(0) { $0 + $1.amount_pence } }
    var annualFree: Int { annualPay - annualBills - monthlyInvestments * 12 }
}

struct PlanInstrument: Codable {
    let symbol: String
    var isin: String?
    var type: String?
    var exchange: String?
    var currency: String?

    var displayIdentifier: String { isin ?? symbol }
}

struct PlanSearchResult: Decodable, Identifiable {
    let name: String
    let instrument: PlanInstrument

    var id: String { instrument.symbol }

    private enum CodingKeys: String, CodingKey { case name }

    init(from decoder: Decoder) throws {
        name = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .name)
        instrument = try PlanInstrument(from: decoder)
    }

    init(name: String, instrument: PlanInstrument) {
        self.name = name
        self.instrument = instrument
    }
}

struct PlannedPurchaseChoice: Identifiable {
    let platform: String
    let name: String
    let monthlyPence: Int
    let instrument: PlanInstrument

    var id: String { "\(platform)/\(instrument.symbol)" }
}

enum FinancePlanSection: String, Identifiable {
    case pay = "take-home pay"
    case bills
    case investments

    var id: Self { self }
    var editTitle: String { "Edit \(rawValue)" }
}

enum FinancePlanService {
    private struct Purchase: Encodable {
        let platform: String
        let symbol: String
        let holdings: Double
        let amount_spent: Double
    }

    static func fetch() async throws -> FinancePlan? {
        try await APIClient.shared.fetch("/finance-plan")
    }

    static func save(_ draft: FinancePlan, section: FinancePlanSection, fallback: FinancePlan) async throws -> FinancePlan {
        var latest = try await fetch() ?? fallback
        switch section {
        case .pay: latest.take_home_monthly_pence = draft.take_home_monthly_pence
        case .bills: latest.bills = draft.bills
        case .investments: latest.allocations = draft.allocations
        }
        return try await APIClient.shared.send("/finance-plan", method: "PUT", body: latest)
    }

    static func accounts() async throws -> [String: [APIInvestment]] {
        let holdings: [String: [APIInvestment]] = try await APIClient.shared.fetch("/holdings/")
        return holdings.filter { $0.key.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Cash") != .orderedSame }
    }

    static func search(_ term: String) async throws -> [PlanSearchResult] {
        var query = URLComponents()
        query.path = "/holdings/search"
        query.queryItems = [URLQueryItem(name: "q", value: term)]
        guard let path = query.string?.replacingOccurrences(of: "+", with: "%2B") else { return [] }
        let results: [PlanSearchResult] = try await APIClient.shared.fetch(path)
        return results.filter { result in
            ["stock", "etf", "fund", "crypto"].contains(result.instrument.type ?? "")
        }
    }

    static func choices() async throws -> [PlannedPurchaseChoice] {
        async let plan = fetch()
        async let portfolio = accounts()
        let (saved, holdings) = try await (plan, portfolio)
        var seen = Set<String>()
        return (saved?.allocations ?? []).filter { holdings[$0.platform] != nil }.flatMap { row in
            row.funds.compactMap { fund in
                guard let instrument = fund.instrument else { return nil }
                let choice = PlannedPurchaseChoice(platform: row.platform, name: fund.name, monthlyPence: fund.amount_pence, instrument: instrument)
                return seen.insert(choice.id).inserted ? choice : nil
            }
        }
    }

    static func record(_ choice: PlannedPurchaseChoice, units: Double, amountSpent: Double) async throws {
        let purchase = Purchase(platform: choice.platform, symbol: choice.instrument.symbol, holdings: units, amount_spent: amountSpent)
        let _: APIInvestment = try await APIClient.shared.send("/finance-plan/purchase", body: purchase)
    }
}
