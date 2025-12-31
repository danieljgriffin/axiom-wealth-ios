import Foundation

// MARK: - API Response Models
// These match the JSON shape returned by finance-api

struct APIInvestment: Codable {
    let id: Int
    let platform: String
    let name: String
    let symbol: String?
    let holdings: Double // Quantity
    let amount_spent: Double // Cost Basis
    let average_buy_price: Double
    let current_price: Double
    let last_updated: String?
}

struct APIPlatformCash: Codable {
    let platform: String
    let cash_balance: Double
    let last_updated: String?
}

struct APINetWorthSummary: Codable {
    let total_networth: Double
    let platform_breakdown: [String: Double]
}

struct APIDashboardSummary: Codable {
    let total_networth: Double
    let platform_breakdown: [String: Double]
    let mom_change: Double?
    let mom_change_percent: Double?
    let ytd_change: Double?
    let ytd_change_percent: Double?
    let platforms: [APIDashboardPlatformItem]?
}

struct APIDashboardPlatformItem: Codable {
    let platform: String
    let value: Double
    let month_change_amount: Double?
    let month_change_percent: Double?
}

struct APIHistoricalDataPoint: Codable {
    let date: String
    let value: Double
    let platform_breakdown: [String: Double]?
}

struct APIGoal: Codable {
    let id: Int
    let title: String
    let description: String?
    let target_amount: Double
    let target_date: String
    let status: String
    let is_primary: Bool?
    let completed_date: String?
}

struct APIPlatformSummary: Codable {
    let name: String
    let total_value: Double
    let total_invested: Double
    let total_pl: Double
    let total_pl_percent: Double
    let cash_balance: Double
    let investments: [APIInvestment]
    let color: String
}

struct APIPortfolioSummary: Codable {
    let total_value: Double
    let total_invested: Double
    let total_pl: Double
    let total_pl_percent: Double
    let platforms: [APIPlatformSummary]
}
