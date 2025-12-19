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
                id: UUID(), // We can't persist Int ID cleanly into UUID without custom logic, but for fetching it's ok.
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
}
