import Foundation

struct MockPortfolioData {
    static let summary = NetWorthSummary(
        currentNetWorth: 120800,
        lastUpdated: Date(),
        monthChange: -5739,
        monthChangePercent: -4.5,
        yearChange: 19928,
        yearChangePercent: 19.8
    )
    
    static let performance: PerformanceSeries = {
        let now = Date()
        let calendar = Calendar.current
        
        func generatePoints(hours: Int, startValue: Double, volatility: Double, trend: Double) -> [NetWorthPoint] {
            var points: [NetWorthPoint] = []
            var currentValue = startValue
            
            for i in 0...hours {
                let date = calendar.date(byAdding: .hour, value: -hours + i, to: now)!
                let randomChange = Double.random(in: -volatility...volatility)
                currentValue += randomChange + trend
                points.append(NetWorthPoint(timestamp: date, value: currentValue))
            }
            return points
        }
        
        // Helper to generate daily points
        func generateDailyPoints(days: Int, startValue: Double, volatility: Double, trend: Double) -> [NetWorthPoint] {
            var points: [NetWorthPoint] = []
            var currentValue = startValue
            
            for i in 0...days {
                let date = calendar.date(byAdding: .day, value: -days + i, to: now)!
                let randomChange = Double.random(in: -volatility...volatility)
                currentValue += randomChange + trend
                points.append(NetWorthPoint(timestamp: date, value: currentValue))
            }
            return points
        }
        
        let baseValue = 120800.0
        
        return PerformanceSeries(
            h24: generatePoints(hours: 24, startValue: baseValue - 100, volatility: 50, trend: 5),
            w1: generateDailyPoints(days: 7, startValue: baseValue - 500, volatility: 200, trend: 50),
            m1: generateDailyPoints(days: 30, startValue: baseValue + 5739, volatility: 300, trend: -150),
            m3: generateDailyPoints(days: 90, startValue: baseValue - 2000, volatility: 400, trend: 30),
            m6: generateDailyPoints(days: 180, startValue: baseValue - 8000, volatility: 500, trend: 50),
            y1: generateDailyPoints(days: 365, startValue: baseValue - 19928, volatility: 600, trend: 60),
            max: generateDailyPoints(days: 730, startValue: 80000, volatility: 800, trend: 50)
        )
    }()
    
    static let platformBreakdown: [PlatformBreakdownItem] = [
        PlatformBreakdownItem(platform: "InvestEngine ISA", value: 35343, percentage: 29.3, monthChange: 120, monthChangePercent: 0.3),
        PlatformBreakdownItem(platform: "HL Stocks & Shares LISA", value: 32717, percentage: 27.1, monthChange: -400, monthChangePercent: -1.2),
        PlatformBreakdownItem(platform: "Crypto", value: 20277, percentage: 16.8, monthChange: -2000, monthChangePercent: -9.0),
        PlatformBreakdownItem(platform: "Degiro", value: 17061, percentage: 14.1, monthChange: 300, monthChangePercent: 1.8),
        PlatformBreakdownItem(platform: "EQ (GSK shares)", value: 9344, percentage: 7.7, monthChange: 50, monthChangePercent: 0.5),
        PlatformBreakdownItem(platform: "Trading212 ISA", value: 5320, percentage: 4.4, monthChange: 100, monthChangePercent: 1.9),
        PlatformBreakdownItem(platform: "Cash", value: 738, percentage: 0.6, monthChange: 0, monthChangePercent: 0.0)
    ]
    

    

    
    // MARK: - New Data Models
    static let platforms: [InvestmentPlatform] = [
        InvestmentPlatform(
            id: UUID(),
            name: "InvestEngine ISA",
            colorHex: "#22C55E", // Green
            investments: [
                InvestmentPosition(id: UUID(), name: "Vanguard S&P 500", symbol: "VUSA.L", shares: 450, averagePrice: 66.66, currentPrice: 78.54),
                InvestmentPosition(id: UUID(), name: "iShares Global Clean Energy", symbol: "INRG.L", shares: 1200, averagePrice: 8.50, currentPrice: 7.20)
            ],
            cashBalance: 0
        ),
        InvestmentPlatform(
            id: UUID(),
            name: "Trading 212",
            colorHex: "#3B82F6", // Blue
            investments: [
                InvestmentPosition(id: UUID(), name: "Tesla", symbol: "TSLA", shares: 15, averagePrice: 240.00, currentPrice: 210.00),
                InvestmentPosition(id: UUID(), name: "Apple", symbol: "AAPL", shares: 25, averagePrice: 150.00, currentPrice: 175.00)
            ],
            cashBalance: 738
        ),
        InvestmentPlatform(
            id: UUID(),
            name: "Crypto",
            colorHex: "#F59E0B", // Orange
            investments: [
                InvestmentPosition(id: UUID(), name: "Bitcoin", symbol: "BTC-USD", shares: 0.45, averagePrice: 33333, currentPrice: 45060),
                InvestmentPosition(id: UUID(), name: "Ethereum", symbol: "ETH-USD", shares: 5.0, averagePrice: 1800, currentPrice: 2200)
            ],
            cashBalance: 0
        )
    ]
}
