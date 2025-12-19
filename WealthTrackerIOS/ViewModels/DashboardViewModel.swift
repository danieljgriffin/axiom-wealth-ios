import SwiftUI
import Combine

// MARK: - Models for Dashboard
struct DashboardSummary {
    let currentNetWorth: Double
    let lastUpdated: Date
    let monthChange: Double
    let monthChangePercent: Double
    let yearChange: Double
    let yearChangePercent: Double
    let platformPerformance: [APIDashboardPlatformItem]?
}



struct DashboardPlatformItem: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let value: Double
    let percentage: Double
    let monthChange: Double
    let monthChangePercent: Double
}

// MARK: - ViewModel
class DashboardViewModel: ObservableObject {
    @Published var summary: DashboardSummary
    @Published var selectedRange: TimeRange = .h24
    @Published var currentSeries: [NetWorthPoint]
    @Published var platforms: [DashboardPlatformItem]
    // @Published var isPrivateMode: Bool = false // Moved to AppStorage in View
    
    init() {
        // Initialize with empty/default state
        self.summary = DashboardSummary(
            currentNetWorth: 0,
            lastUpdated: Date(),
            monthChange: 0,
            monthChangePercent: 0,
            yearChange: 0,
            yearChangePercent: 0,
            platformPerformance: nil
        )
        self.platforms = []
        self.currentSeries = []
    }
    
    func update(with sourcePlatforms: [InvestmentPlatform]) {
        // Build breakdown locally to preserve Colors which come from InvestmentPlatform
        let totalValue = sourcePlatforms.reduce(0) { $0 + $1.totalValue }
        
        // Calculate Breakdown
        // Calculate Breakdown
        self.platforms = sourcePlatforms.map { platform in
            let platformValue = platform.totalValue
            let percentage = totalValue > 0 ? (platformValue / totalValue) * 100 : 0
            
            // Try to find performance data from the last fetched summary
            var monthChange: Double = 0
            var monthChangePercent: Double = 0
            
            if let perfData = self.summary.platformPerformance {
                if let match = perfData.first(where: { $0.platform == platform.name }) {
                    monthChange = match.month_change_amount ?? 0
                    monthChangePercent = match.month_change_percent ?? 0
                }
            }
            
            return DashboardPlatformItem(
                name: platform.name,
                color: Color(hex: platform.colorHex),
                value: platformValue,
                percentage: percentage,
                monthChange: monthChange,
                monthChangePercent: monthChangePercent
            )
        }.sorted(by: { $0.value > $1.value })
        
        // Trigger fetch for Summary and History
        Task {
            await fetchApiData()
        }
    }
    
    func updateRange(_ range: TimeRange) {
        selectedRange = range
        Task {
            await fetchHistory()
        }
    }
    
    @MainActor
    private func fetchApiData() async {
        do {
            // 1. Fetch Summary
            let apiSummary = try await WealthService.shared.fetchDashboardSummary()
            self.summary = apiSummary
            
            // Re-apply performance data to existing platforms
            // We need to trigger the update logic again.
            // Since we don't store the raw [InvestmentPlatform] source needed for update(),
            // ideally we should structure this better.
            // BUT, for now, we can iterate self.platforms (which are DashboardPlatformItems) 
            // and update them in place, or we can just rely on the next refresh?
            // User wants to see it. 
            // BETTER: We can just re-map self.platforms using the new summary data.
            // However, we lost the `InvestmentPlatform` source (cashBalance, colorHex etc were mapped).
            // Actually, we can just update the `monthChange` fields of the existing items!
            
            if let perfData = self.summary.platformPerformance {
                 self.platforms = self.platforms.map { item in
                     var newItem = item
                     if let match = perfData.first(where: { $0.platform == item.name }) {
                         // Create new item with updated stats (structs are immutable)
                         return DashboardPlatformItem(
                             name: item.name,
                             color: item.color,
                             value: item.value,
                             percentage: item.percentage,
                             monthChange: match.month_change_amount ?? 0,
                             monthChangePercent: match.month_change_percent ?? 0
                         )
                     }
                     return item
                 }
            }
            
            // 2. Fetch History
            await fetchHistory()
        } catch {
            print("Error fetching dashboard data: \(error)")
        }
    }
    
    @MainActor
    private func fetchHistory() async {
        do {
            let points = try await WealthService.shared.fetchDashboardHistory(period: selectedRange.apiPeriod)
            withAnimation {
                self.currentSeries = points
            }
        } catch {
            print("Error fetching history: \(error)")
        }
    }
    
    // Helper for Y-axis ticks
    var yAxisTicks: [Double] {
        guard !currentSeries.isEmpty else { return [] }
        let values = currentSeries.map { $0.value }
        let min = values.min() ?? 0
        let max = values.max() ?? 100
        
        if min == max {
            return [min * 0.9, min, min * 1.1]
        }
        
        let range = max - min
        let step = range / 4
        return [min, min + step, min + step * 2, min + step * 3, max]
    }
    
    // Helper for Y-axis domain
    var yAxisDomain: ClosedRange<Double> {
        guard !currentSeries.isEmpty else { return 0...100 }
        let values = currentSeries.map { $0.value }
        let min = values.min() ?? 0
        let max = values.max() ?? 100
        
        if min == max {
            return (min * 0.9)...(min * 1.1)
        }
        
        // Add a little padding (e.g. 1% of range)
        let range = max - min
        let padding = range * 0.05
        return (min - padding)...(max + padding)
    }
}
