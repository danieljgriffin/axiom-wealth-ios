import Foundation
import SwiftUI
import Combine

class InvestmentsViewModel: ObservableObject {
    @Published var platforms: [InvestmentPlatform] = []
    @Published var isLoading = false
    
    // Summary properties
    var totalValue: Double {
        platforms.reduce(0) { $0 + $1.totalValue }
    }
    
    var totalInvestedCost: Double {
        platforms.reduce(0) { $0 + $1.totalInvestedCost }
    }
    
    var totalCostBasis: Double {
        platforms.reduce(0) { $0 + $1.totalCostBasis }
    }
    
    var totalProfitLoss: Double {
        platforms.reduce(0) { $0 + $1.totalProfitLoss }
    }
    
    var totalProfitLossPercent: Double {
        guard totalInvestedCost != 0 else { return 0 }
        return (totalProfitLoss / totalInvestedCost) * 100
    }
    
    init() {
        Task {
            await loadData()
        }
    }
    
    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedPlatforms = try await WealthService.shared.fetchHoldings()
            self.platforms = fetchedPlatforms
        } catch {
            print("Error loading holdings: \(error)")
            // Fallback to empty or keep existing?
            // For now, if we fail, we might show empty or last known if we cached.
            // But we removed persistence.
        }
    }
    
    @MainActor
    func refreshPrices() async {
        // Since backend handles pricing, refreshing prices is just reloading data
        await loadData()
    }
    
    // MARK: - Mutations
    // Note: These currently update local state only. 
    // To fully sync, we need to implement API POST/PUT/DELETE calls in WealthService.
    // For this task (Read-only integration focus check?), we prioritize reading.
    
    func addPlatform(name: String, colorHex: String) {
        // Todo: Call API
    }
    
    func addInvestment(to platformId: UUID, investment: InvestmentPosition) {
        // Todo: Call API
    }
    
    func deletePlatform(id: UUID) {
        // Todo: Call API
    }
    
    func deleteInvestment(id: UUID, from platformId: UUID) {
        // Todo: Call API
    }
    
    func updatePlatform(_ platform: InvestmentPlatform) {
       // Todo: Call API
    }
    
    func updateInvestment(in platformId: UUID, investment: InvestmentPosition) {
        // Todo: Call API
    }
    
    @MainActor
    func addTrading212Platform(apiKey: String, apiSecret: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let service = Trading212Service()
        
        // 1. Fetch Portfolio
        let positions = try await service.fetchPortfolio(apiKey: apiKey, apiSecret: apiSecret)
        
        // 2. Fetch USD/GBP Rate
        let usdRate = (try? await MarketDataService.shared.fetchCurrentPrice(for: "USDGBP=X")) ?? 0.77
        
        // 3. Prepare Symbols (Normalization Only)
        struct PositionMeta {
            let position: Trading212Position
            let cleanSymbol: String
        }
        
        let mappedPositions = positions.map { pos -> PositionMeta in
            var cleanSymbol = pos.ticker
            
            // Normalization Rules
            if pos.ticker.hasSuffix("_US_EQ") {
                cleanSymbol = pos.ticker.replacingOccurrences(of: "_US_EQ", with: "")
            } else if pos.ticker.hasSuffix("_EQ") {
                let base = pos.ticker.replacingOccurrences(of: "_EQ", with: "")
                if base.hasSuffix("l") {
                    cleanSymbol = String(base.dropLast()) + ".L"
                } else {
                    cleanSymbol = base
                }
            }
            
            return PositionMeta(position: pos, cleanSymbol: cleanSymbol)
        }
        
        // 2. Fetch Metadata (Price, Name)
        // We use a legacy mapping for known rebrands (e.g. FB -> META) to ensure correct resolution
        // while keeping the rest of the system dynamic.
        let legacyMapping: [String: String] = ["FB": "META"]
        
        let uniqueSymbols = Set(mappedPositions.map { $0.cleanSymbol })
        var searchSymbols = Set<String>()
        
        // Prepare symbols for fetching (map FB -> META)
        for symbol in uniqueSymbols {
            let searchSym = legacyMapping[symbol] ?? symbol
            searchSymbols.insert(searchSym)
        }
        
        // Fetch metadata for the resolved symbols (e.g. META)
        let metadata = await MarketDataService.shared.fetchMetadata(for: Array(searchSymbols))
        
        var finalMetadata = metadata
        
        // B. Identify "Unknowns" (symbols that returned no name/metadata)
        // If metadata[symbol] is nil OR name is nil/empty, it's a candidate for search
        for symbol in uniqueSymbols { // Iterate original clean symbols
            let resolvedSymbol = legacyMapping[symbol] ?? symbol // Get the potentially mapped symbol
            if finalMetadata[resolvedSymbol]?.name == nil {
                // Smart Fallback: Search for the symbol
                let searchResults = await MarketDataService.shared.search(query: resolvedSymbol)
                if let bestMatch = searchResults.first {
                    // Update metadata with search result
                    finalMetadata[resolvedSymbol] = MarketMetadata(
                        symbol: bestMatch.symbol, // Use the new symbol (e.g. META)
                        name: bestMatch.name,
                        currency: nil, // We don't get currency from search easily, but that's fine
                        regularMarketPrice: bestMatch.currentPrice
                    )
                }
            }
        }
        
        // 5. Map to InvestmentPosition
        let investments = mappedPositions.map { item -> InvestmentPosition in
            let pos = item.position
            let originalCleanSymbol = item.cleanSymbol
            
            var currentPrice = pos.currentPrice
            var averagePrice = pos.averagePrice
            
            // Currency Conversion Logic (Replit Rules)
            if pos.ticker.hasSuffix("_US_EQ") {
                currentPrice *= usdRate
                averagePrice *= usdRate
            } else if pos.ticker.hasSuffix("_EQ") {
                currentPrice /= 100.0
                averagePrice /= 100.0
            }
            
            // Name Logic: Use Smart Metadata
            // Note: If search found a new symbol (FB->META), we might want to use that as the display symbol too.
            let resolvedSym = legacyMapping[originalCleanSymbol] ?? originalCleanSymbol
            let meta = finalMetadata[resolvedSym]
            let name = meta?.name ?? originalCleanSymbol
            let displaySymbol = meta?.symbol ?? originalCleanSymbol
            
            return InvestmentPosition(
                id: UUID(),
                name: name,
                symbol: displaySymbol,
                amountSpent: nil, // Fallback to shares * avgPrice
                shares: pos.quantity,
                averagePrice: averagePrice,
                currentPrice: currentPrice
            )
        }
        
        // Check if Trading 212 platform already exists
        if let index = platforms.firstIndex(where: { $0.name == "Trading 212" }) {
            // Update existing
            platforms[index].investments = investments
            saveToPersistence()
        } else {
            // Create new
            let newPlatform = InvestmentPlatform(
                id: UUID(),
                name: "Trading 212",
                colorHex: "#3B82F6", // Blue color
                investments: investments,
                cashBalance: 0
            )
            platforms.append(newPlatform)
            saveToPersistence()
        }
    }
    
    func updatePlatformCash(platformId: UUID, amount: Double) {
        // Find platform name
        guard let platform = platforms.first(where: { $0.id == platformId }) else { return }
        
        Task {
            isLoading = true
             defer { isLoading = false }
            do {
                try await WealthService.shared.updatePlatformCash(platformName: platform.name, amount: amount)
                await loadData() // Refresh to show new balance
            } catch {
                print("Failed to update cash: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private let persistenceKey = "WealthTracker_Platforms"
    
    private func saveToPersistence() {
        if let encoded = try? JSONEncoder().encode(platforms) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }
    
    private func loadFromPersistence() -> Bool {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let decoded = try? JSONDecoder().decode([InvestmentPlatform].self, from: data) {
            self.platforms = decoded
            return true
        }
        return false
    }
}
