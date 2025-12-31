import SwiftUI
import Combine

struct AddInvestmentView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: InvestmentsViewModel
    var investmentToEdit: InvestmentPosition?
    var editingPlatformId: UUID?
    
    // Form State
    @State private var selectedPlatformId: UUID?
    @State private var searchQuery = ""
    @State private var searchResults: [InvestmentSearchResult] = []
    @State private var isSearching = false
    
    @State private var isConnectingWallet = false
    @State private var xpubAddress = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Selected Investment Details
    @State private var name = ""
    @State private var symbol = ""
    @State private var currentPrice = ""
    

    
    // Cost Entry
    @State private var shares = ""
    @State private var totalCost = ""
    @State private var averagePrice = ""
    
    // Focus State for calculations
    @FocusState private var focusedField: Field?
    enum Field {
        case shares, totalCost, averagePrice
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Platform Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Platform")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Menu {
                                ForEach(viewModel.platforms) { platform in
                                    Button(platform.name) {
                                        selectedPlatformId = platform.id
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedPlatformName)
                                        .foregroundColor(selectedPlatformId == nil ? .gray : .white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.cardBg)
                                .cornerRadius(12)
                            }
                        }
                        
                        if investmentToEdit == nil {
                            // 2. Mode Selector (Manual vs Wallet)
                            HStack {
                                Button(action: { isConnectingWallet = false }) {
                                    Text("Manual Entry")
                                        .fontWeight(.medium)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(isConnectingWallet ? Color.clear : Color.blue)
                                        .foregroundColor(isConnectingWallet ? .gray : .white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: { isConnectingWallet = true }) {
                                    Text("Connect Wallet")
                                        .fontWeight(.medium)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(isConnectingWallet ? Color.blue : Color.clear)
                                        .foregroundColor(isConnectingWallet ? .white : .gray)
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if isConnectingWallet {
                            // --- WALLET MODE ---
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Bitcoin Wallet (Read-Only)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 16) {
                                    TextField("Wallet Name (e.g. Trezor)", text: $name)
                                        .padding()
                                        .background(Color.cardBg)
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        TextField("XPUB Address", text: $xpubAddress)
                                            .padding()
                                            .background(Color.cardBg)
                                            .cornerRadius(12)
                                            .foregroundColor(.white)
                                        
                                        Text("Paste your XPUB/ZPUB public key. We never ask for private keys.")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        } else {
                            // --- MANUAL MODE ---
                            // 3. Smart Search
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Find Investment")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    TextField("Ticker (e.g. SGLN) or ISIN", text: $searchQuery)
                                        .padding()
                                        .background(Color.cardBg)
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                        .onChange(of: searchQuery) { _, newValue in
                                            performSearch(query: newValue)
                                        }
                                    
                                    if isSearching {
                                        ProgressView()
                                            .tint(.white)
                                            .padding(.leading, 8)
                                    }
                                }
                                
                                if !searchResults.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults) { result in
                                            Button {
                                                selectInvestment(result)
                                            } label: {
                                                HStack {
                                                    VStack(alignment: .leading) {
                                                        Text(result.name)
                                                            .font(.body)
                                                            .foregroundColor(.white)
                                                        Text(result.symbol)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                    Spacer()
                                                    if result.currentPrice > 0 {
                                                        Text(String(format: "%.2f", result.currentPrice))
                                                            .font(.body)
                                                            .foregroundColor(.positiveGreen)
                                                    }
                                                }
                                                .padding()
                                                .background(Color.cardBg)
                                            }
                                            Divider().background(Color.gray.opacity(0.3))
                                        }
                                    }
                                    .cornerRadius(12)
                                    .padding(.top, 4)
                                }
                            }
                            
                            // 4. Details & Cost
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Details")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 12) {
                                    if !name.isEmpty {
                                        DetailRow(label: "Name", value: name)
                                        DetailRow(label: "Current Price", value: "£" + currentPrice)
                                        Divider().background(Color.gray.opacity(0.3))
                                    }
                                    
                                    CustomTextField(label: "Shares", text: $shares, focused: $focusedField, field: .shares)
                                        .keyboardType(.decimalPad)
                                        .onChange(of: shares) { _, _ in recalculateFromShares() }
                                    
                                    CustomTextField(label: "Average Price", text: $averagePrice, focused: $focusedField, field: .averagePrice)
                                        .keyboardType(.decimalPad)
                                        .onChange(of: averagePrice) { _, _ in recalculateFromAvgPrice() }
                                    
                                    CustomTextField(label: "Total Cost", text: $totalCost, focused: $focusedField, field: .totalCost)
                                        .keyboardType(.decimalPad)
                                        .onChange(of: totalCost) { _, _ in recalculateFromTotalCost() }
                                }
                                .padding()
                                .background(Color.cardBg)
                                .cornerRadius(12)
                            }
                            
                        } // End else
                    }
                    .padding()
                }
                }
                .onAppear {
                    if let investment = investmentToEdit {
                        name = investment.name
                        symbol = investment.symbol ?? ""
                        currentPrice = String(format: "%.2f", investment.currentPrice)
                        shares = String(format: "%g", investment.shares)
                        averagePrice = String(format: "%.2f", investment.averagePrice)
                        totalCost = String(format: "%.2f", investment.costBasis)
                        
                        // Populate Search Query so user sees what they are editing
                        searchQuery = investment.symbol ?? investment.name
                        
                        // robust Platform Selection
                        // 1. Try passed ID
                        if let platformId = editingPlatformId {
                            selectedPlatformId = platformId
                        }
                        
                        // 2. Fallback: Find platform containing this investment
                        if selectedPlatformId == nil {
                            if let foundPlatform = viewModel.platforms.first(where: { plt in
                                plt.investments.contains(where: { $0.id == investment.id })
                            }) {
                                selectedPlatformId = foundPlatform.id
                            }
                        }
                    }
                }

            .navigationTitle(investmentToEdit == nil ? "Add Investment" : "Edit Investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInvestment()
                    }
                    .disabled(!isValid)
                    .foregroundColor(!isValid ? .gray : .blue)
                }
            }
            .preferredColorScheme(.dark)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    var selectedPlatformName: String {
        if let id = selectedPlatformId, let platform = viewModel.platforms.first(where: { $0.id == id }) {
            return platform.name
        }
        return "Select Platform"
    }
    
    var isValid: Bool {
        if selectedPlatformId == nil { return false }
        if name.isEmpty { return false }
        
        if isConnectingWallet {
            return !xpubAddress.isEmpty
        } else {
            return !shares.isEmpty
        }
    }
    
    // MARK: - Logic
    
    private func performSearch(query: String) {
        Task {
            if query.isEmpty {
                searchResults = []
                isSearching = false
                return
            }
            
            // Suppress initial search if it matches what we are editing
            if let editing = investmentToEdit {
                if query == editing.symbol || query == editing.name {
                    return
                }
            }
            
            isSearching = true
            // Debounce could be added here
            searchResults = await MarketDataService.shared.search(query: query)
            isSearching = false
        }
    }
    
    private func selectInvestment(_ result: InvestmentSearchResult) {
        name = result.name
        symbol = result.symbol
        searchQuery = ""
        searchResults = []
        
        // Use the price we already found during search if possible
        if result.currentPrice > 0 {
            currentPrice = String(format: "%.2f", result.currentPrice)
        } else {
            Task {
                if let price = try? await MarketDataService.shared.fetchCurrentPrice(for: result.symbol) {
                    currentPrice = String(format: "%.2f", price)
                }
            }
        }
        
        focusedField = .shares
    }
    
    // MARK: - Dynamic Calculations
    
    private func recalculateFromShares() {
        if let s = Double(shares), let t = Double(totalCost), s != 0 {
            averagePrice = String(format: "%.2f", t / s)
        }
    }
    
    private func recalculateFromAvgPrice() {
        if focusedField == .averagePrice {
            if let s = Double(shares), let a = Double(averagePrice) {
                totalCost = String(format: "%.2f", s * a)
            }
        }
    }
    
    private func recalculateFromTotalCost() {
        if focusedField == .totalCost {
            if let s = Double(shares), let t = Double(totalCost), s != 0 {
                averagePrice = String(format: "%.2f", t / s)
            }
        }
    }
    
    private func saveInvestment() {
        guard let platformId = selectedPlatformId else { return }
        
        if isConnectingWallet {
            // Crypto Flow
            let platformName = selectedPlatformName
            Task {
                do {
                    try await viewModel.connectCryptoInvestment(platformName: platformName, name: name, xpub: xpubAddress)
                    dismiss()
                } catch {
                    print("Failed to connect wallet: \(error)")
                    errorMessage = "Failed to connect: \(error.localizedDescription)"
                    showError = true
                }
            }
            return
        }
        
        // Manual Flow
        guard let sharesDouble = Double(shares),
              let avgPriceDouble = Double(averagePrice),
              let currPriceDouble = Double(currentPrice) else { return }
        
        if let originalInvestment = investmentToEdit {
            var updatedInvestment = originalInvestment
            updatedInvestment.name = name
            updatedInvestment.symbol = symbol.isEmpty ? nil : symbol
            updatedInvestment.shares = sharesDouble
            updatedInvestment.averagePrice = avgPriceDouble
            updatedInvestment.currentPrice = currPriceDouble
            
            viewModel.updateInvestment(in: platformId, investment: updatedInvestment)
        } else {
            let newInvestment = InvestmentPosition(
                id: UUID(),
                name: name,
                symbol: symbol.isEmpty ? nil : symbol,
                shares: sharesDouble,
                averagePrice: avgPriceDouble,
                currentPrice: currPriceDouble
            )
            
            viewModel.addInvestment(to: platformId, investment: newInvestment)
        }
        dismiss()
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.white)
        }
    }
}

struct CustomTextField: View {
    let label: String
    @Binding var text: String
    var focused: FocusState<AddInvestmentView.Field?>.Binding
    let field: AddInvestmentView.Field
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.gray)
            Spacer()
            TextField("0.00", text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.white)
                .focused(focused, equals: field)
        }
    }
}
