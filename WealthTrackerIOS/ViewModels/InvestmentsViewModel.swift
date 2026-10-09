import Foundation
import SwiftUI
import Combine

class InvestmentsViewModel: ObservableObject {
    @Published var platforms: [InvestmentPlatform] = []
    @Published var isLoading = false
    
    // Error Handling
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
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
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await WealthService.shared.createPlatform(name: name, colorHex: colorHex)
                await loadData()
            } catch {
                print("Failed to add platform: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to add platform: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func addInvestment(to platformId: UUID, investment: InvestmentPosition) {
        guard let platform = platforms.first(where: { $0.id == platformId }) else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await WealthService.shared.addManualInvestment(
                    platform: platform.name,
                    name: investment.name,
                    symbol: investment.symbol,
                    shares: investment.shares,
                    amountSpent: investment.costBasis,
                    averagePrice: investment.averagePrice,
                    currentPrice: investment.currentPrice
                )
                await loadData()
            } catch {
                print("Failed to add investment: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to add investment: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func deletePlatform(id: UUID) {
        // Find the platform by ID
        guard let platform = platforms.first(where: { $0.id == id }) else { return }
        
        Task {
            do {
                try await WealthService.shared.deletePlatform(name: platform.name)
                await loadData()
            } catch {
                print("Failed to delete platform: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to delete platform: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func deleteInvestment(id: UUID, from platformId: UUID) {
        // Find platform and investment
        guard let platform = platforms.first(where: { $0.id == platformId }),
              let investment = platform.investments.first(where: { $0.id == id }),
              let backendId = investment.backendId else {
            print("Cannot delete investment: Missing backend ID")
            Task { @MainActor in
                self.errorMessage = "Cannot delete this investment: Missing Backend ID. Try pulling to refresh."
                self.showError = true
            }
            return
        }
        
        Task {
            do {
                try await WealthService.shared.deleteInvestment(id: backendId)
                await loadData()
            } catch {
                print("Failed to delete investment: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to delete investment: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func updatePlatform(_ platform: InvestmentPlatform) {
       // Platform update logic (rename/color) is separate.
    }
    
    func updateInvestment(in platformId: UUID, investment: InvestmentPosition) {
        // We need the backendID to update. 
        // Note: The 'investment' passed here is the NEW state from the form, but it should preserve the ID from the original.
        guard let backendId = investment.backendId else {
             print("Cannot update investment: Missing backend ID")
             Task { @MainActor in
                 self.errorMessage = "Cannot update: Missing Backend ID."
                 self.showError = true
             }
             return
        }
        
        guard let platform = platforms.first(where: { $0.id == platformId }) else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await WealthService.shared.updateManualInvestment(
                    id: backendId,
                    platform: platform.name, // Allow moving platforms if UI supports it
                    name: investment.name,
                    symbol: investment.symbol,
                    shares: investment.shares,
                    amountSpent: investment.costBasis,
                    averagePrice: investment.averagePrice,
                    currentPrice: investment.currentPrice
                )
                await loadData()
            } catch {
               print("Failed to update investment: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to update investment: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    @MainActor
    func addTrading212Platform(
        apiKey: String,
        apiSecret: String,
        accountType: String
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        // The backend validates, encrypts and stores the account-scoped key, then
        // performs the first sync. This keeps iOS and web on one source of truth.
        try await WealthService.shared.connectTrading212(
            apiKey: apiKey,
            apiSecret: apiSecret,
            accountType: accountType
        )
        await loadData()
    }
    
    @MainActor
    func connectCryptoInvestment(platformName: String, name: String, xpub: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await WealthService.shared.connectCryptoInvestment(platformName: platformName, name: name, xpub: xpub)
        
        // Refresh data to show new investment
        await loadData()
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
