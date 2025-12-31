import Foundation
import SwiftUI

// Service to bridge APIClient and iOS Domain Models
class WealthService {
    static let shared = WealthService()
    
    private let api = APIClient.shared
    
    // MARK: - Dashboard
    
    func fetchDashboardSummary() async throws -> DashboardSummary {
        // finance-web uses /net-worth/dashboard-summary
        // or checks /net-worth/summary
        
        let apiSummary: APIDashboardSummary = try await api.fetch("/net-worth/dashboard-summary")
        
        return DashboardSummary(
            currentNetWorth: apiSummary.total_networth, 
            lastUpdated: Date(), // API doesn't send this explicitly yet
            monthChange: apiSummary.mom_change ?? 0,
            monthChangePercent: apiSummary.mom_change_percent ?? 0,
            yearChange: apiSummary.ytd_change ?? 0,
            yearChangePercent: apiSummary.ytd_change_percent ?? 0,
            platformPerformance: apiSummary.platforms // Map the breakdown performance list
        )
    }
    
    func fetchDashboardHistory(period: String = "1y") async throws -> [NetWorthPoint] {
        // Map period to graph-data param
        let data: [APIHistoricalDataPoint] = try await api.fetch("/net-worth/graph-data?period=\(period)")
        
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS" // Python default for microsecond precision
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let isoFormatterSeconds = DateFormatter()
        isoFormatterSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        isoFormatterSeconds.locale = Locale(identifier: "en_US_POSIX")
        
        return data.compactMap { point in
            var date: Date? = nil
            
            // Try 1: Simple Date (Long periods)
            if point.date.count == 10 {
                date = simpleFormatter.date(from: point.date)
            } else {
                // Try 2: Full Precision ISO (Short periods)
                date = isoFormatter.date(from: point.date)
                
                // Try 3: Seconds precision ISO
                if date == nil {
                     date = isoFormatterSeconds.date(from: point.date)
                }
                
                // Try 4: Standard ISO8601 for safety
                if date == nil {
                    let standardIso = ISO8601DateFormatter()
                    standardIso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    date = standardIso.date(from: point.date)
                }
            }
            
            guard let validDate = date else { 
                print("Failed to parse date: \(point.date)")
                return nil 
            }
            return NetWorthPoint(timestamp: validDate, value: point.value)
        }
    }
    
    // MARK: - Holdings
    
    func fetchHoldings() async throws -> [InvestmentPlatform] {
        // Fetch centralized portfolio summary (Fast, 1 request)
        let summary: APIPortfolioSummary = try await api.fetch("/holdings/portfolio")
        
        var platforms: [InvestmentPlatform] = []
        
        for apiPlatform in summary.platforms {
            // Map Investments
            let domainInvestments = apiPlatform.investments.map { apiInv -> InvestmentPosition in
                return InvestmentPosition(
                    id: UUID(),
                    backendId: apiInv.id,
                    name: apiInv.name,
                    symbol: apiInv.symbol,
                    amountSpent: apiInv.amount_spent,
                    shares: apiInv.holdings,
                    averagePrice: apiInv.average_buy_price,
                    currentPrice: apiInv.current_price
                )
            }
            
            let platform = InvestmentPlatform(
                id: UUID(),
                name: apiPlatform.name,
                colorHex: apiPlatform.color,
                investments: domainInvestments,
                cashBalance: apiPlatform.cash_balance
            )
            
            platforms.append(platform)
        }
        
        // Sorting is already done by backend, but we can respect it here by just returning
        return platforms
    }
    
    // MARK: - Goals
    
    func fetchGoals() async throws -> [Goal] {
        let apiGoals: [APIGoal] = try await api.fetch("/goals/")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return apiGoals.map { apiGoal in
            let date = formatter.date(from: apiGoal.target_date) ?? Date()
            
            return Goal(
                id: UUID(), // Local UI ID
                backendId: apiGoal.id, // Store Backend ID
                title: apiGoal.title,
                targetAmount: apiGoal.target_amount,
                targetDate: date,
                isCompleted: apiGoal.status == "COMPLETED" || apiGoal.status == "ACHIEVED",
                completedDate: nil,
                createdAt: Date()
            )
        }
    }
    
    // MARK: - Mutations
    
    func updatePlatformCash(platformName: String, amount: Double) async throws {
        // Endpoint: POST /holdings/cash/{platform} with body { "cash_balance": amount }
        guard let encodedName = platformName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw URLError(.badURL)
        }
        
        let body: [String: Double] = ["cash_balance": amount]
        
        // Using "discardableResult" fetch or expecting APIPlatformCash
        let _: APIPlatformCash = try await api.send("/holdings/cash/\(encodedName)", method: "POST", body: body)
    }
    
    func createGoal(title: String, targetAmount: Double, targetDate: Date) async throws -> Goal {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let request = CreateGoalRequest(
            title: title,
            target_amount: targetAmount,
            target_date: formatter.string(from: targetDate),
            status: "ACTIVE",
            is_primary: false
        )
        
        let apiGoal: APIGoal = try await api.send("/goals/", method: "POST", body: request)
         
        // Return mapped Goal
        let date = formatter.date(from: apiGoal.target_date) ?? Date()
        return Goal(
            id: UUID(),
            backendId: apiGoal.id,
            title: apiGoal.title,
            targetAmount: apiGoal.target_amount,
            targetDate: date,
            isCompleted: false,
            completedDate: nil,
            createdAt: Date()
        )
    }
    
    func updateGoal(id: Int, isCompleted: Bool? = nil, completedDate: Date? = nil, targetAmount: Double? = nil, targetDate: Date? = nil, title: String? = nil) async throws {
        var status: String?
        if let isCompleted = isCompleted {
            status = isCompleted ? "ACHIEVED" : "ACTIVE"
        }
        
        var dateString: String?
        if let date = targetDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dateString = formatter.string(from: date)
        }
        
        let request = UpdateGoalRequest(
            title: title,
            status: status,
            target_amount: targetAmount,
            target_date: dateString
        )
        
        let _: APIGoal = try await api.send("/goals/\(id)", method: "PATCH", body: request)
    }
    func createPlatform(name: String, colorHex: String) async throws {
        // 1. Ensure platform exists by setting 0 cash (if not already existing)
        // This effectively "creates" it in the backend's view if it has no investments yet.
        // If it exists, this just sets cash to 0 (or preserves if we change logic, but here we assume new).
        // Actually, if we just want to register it, setting cash is a safe bet.
        try await updatePlatformCash(platformName: name, amount: 0)
        
        // 2. Set the color
        try await updatePlatformColor(platformName: name, colorHex: colorHex)
    }
    
    func updatePlatformColor(platformName: String, colorHex: String) async throws {
        // Endpoint: POST /holdings/platform/color?platform=...&color=...
        // But checking router: @router.post("/platform/color") params are query params by default in FastAPI if not Body
        // Let's check router signature: 
        // def update_platform_color(platform: str, color: str, ...)
        // Yes, query params.
        
        guard let encodedName = platformName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedColor = colorHex.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        // We use discardable result
        let _: [String: String] = try await api.send("/holdings/platform/color?platform=\(encodedName)&color=\(encodedColor)", method: "POST", body: nil as String?)
    }

    func connectCryptoInvestment(platformName: String, name: String, xpub: String) async throws {
        let request = ConnectCryptoRequest(
            platform_id: platformName,
            name: name,
            xpub: xpub,
            user_id: 1 // Hardcoded for now, similar to other services
        )
        
        // We use discardable result since we just want to trigger it
        let _: ConnectCryptoResponse = try await api.send("/crypto/connect-investment", method: "POST", body: request)
    }

    func deletePlatform(name: String) async throws {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw URLError(.badURL)
        }
        let _: [String: String] = try await api.send("/holdings/platform/\(encodedName)", method: "DELETE", body: nil as Bool?)
    }
    
    func deleteInvestment(id: Int) async throws {
        let _: [String: String] = try await api.send("/holdings/\(id)", method: "DELETE", body: nil as Bool?)
    }
    func addManualInvestment(platform: String, name: String, symbol: String?, shares: Double, amountSpent: Double, averagePrice: Double, currentPrice: Double) async throws {
        let request = InvestmentCreateRequest(
            platform: platform,
            name: name,
            symbol: symbol,
            holdings: shares,
            amount_spent: amountSpent,
            average_buy_price: averagePrice,
            current_price: currentPrice
        )
        // API returns the created object, but we discard it and reload via fetchHoldings
        let _: APIInvestment = try await api.send("/holdings/", method: "POST", body: request)
    }
    
    func updateManualInvestment(id: Int, platform: String?, name: String?, symbol: String?, shares: Double?, amountSpent: Double?, averagePrice: Double?, currentPrice: Double?) async throws {
        let request = InvestmentUpdateRequest(
            platform: platform,
            name: name,
            symbol: symbol,
            holdings: shares,
            amount_spent: amountSpent,
            average_buy_price: averagePrice,
            current_price: currentPrice
        )
        // API returns updated object
        let _: APIInvestment = try await api.send("/holdings/\(id)", method: "PUT", body: request)
    }
}

// MARK: - Private Request Models
private struct ConnectCryptoRequest: Encodable {
    let platform_id: String
    let name: String
    let xpub: String
    let user_id: Int
}

private struct ConnectCryptoResponse: Codable {
    let status: String
    let investment_id: Int
    let wallet_id: Int
    let message: String
}

private struct CreateGoalRequest: Encodable {
    let title: String
    let target_amount: Double
    let target_date: String
    let status: String
    let is_primary: Bool
}

private struct UpdateGoalRequest: Encodable {
    let title: String?
    let status: String?
    let target_amount: Double?
    let target_date: String?
}

private struct InvestmentCreateRequest: Encodable {
    let platform: String
    let name: String
    let symbol: String?
    let holdings: Double
    let amount_spent: Double
    let average_buy_price: Double
    let current_price: Double
}

private struct InvestmentUpdateRequest: Encodable {
    let platform: String?
    let name: String?
    let symbol: String?
    let holdings: Double?
    let amount_spent: Double?
    let average_buy_price: Double?
    let current_price: Double?
}
