import Foundation
import SwiftUI

struct InvestmentPlatform: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String // e.g., "Trading 212", "Barclays"
    var colorHex: String // For UI theming
    var investments: [InvestmentPosition]
    var cashBalance: Double // Uninvested cash
    
    // Computed properties for UI
    var totalValue: Double {
        investments.reduce(0) { $0 + $1.currentValue } + cashBalance
    }
    
    var totalProfitLoss: Double {
        totalValue - totalInvestedCost
    }
    
    var totalInvestedCost: Double {
        investments.reduce(0) { $0 + $1.costBasis }
    }
    
    var totalCostBasis: Double {
        totalInvestedCost + cashBalance
    }
    
    var totalProfitLossPercent: Double {
        guard totalInvestedCost != 0 else { return 0 }
        return (totalProfitLoss / totalInvestedCost) * 100
    }
    
    static func == (lhs: InvestmentPlatform, rhs: InvestmentPlatform) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.colorHex == rhs.colorHex &&
               lhs.investments == rhs.investments &&
               lhs.cashBalance == rhs.cashBalance
    }
}

struct InvestmentPosition: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String // e.g., "Vanguard S&P 500"
    var symbol: String? // e.g., "VUSA.L"
    var amountSpent: Double? // Preferred over shares * averagePrice
    var shares: Double
    var averagePrice: Double
    var currentPrice: Double
    
    // Computed
    var costBasis: Double { 
        if let spent = amountSpent, spent != 0 {
             return spent
        }
        return shares * averagePrice 
    }
    var currentValue: Double { shares * currentPrice }
    var profitLoss: Double { currentValue - costBasis }
    var profitLossPercent: Double {
        guard costBasis != 0 else { return 0 }
        return (profitLoss / costBasis) * 100
    }
}
