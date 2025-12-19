import SwiftUI

struct InvestmentsView: View {
    @EnvironmentObject var viewModel: InvestmentsViewModel
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    
    @State private var showingAddOptions = false
    @State private var showingAddPlatform = false
    @State private var showingAddInvestment = false
    
    // Edit & Delete State
    @State private var platformToEdit: InvestmentPlatform?
    @State private var investmentToEdit: InvestmentPosition?
    @State private var editingPlatformId: UUID?
    
    @State private var platformToDelete: InvestmentPlatform?
    @State private var showingDeletePlatformAlert = false
    
    @State private var investmentToDelete: InvestmentPosition?
    @State private var investmentToDeletePlatformId: UUID?
    @State private var showingDeleteInvestmentAlert = false
    
    // Cash Edit State
    @State private var editingCashPlatformId: UUID?
    @State private var editingCashValue: String = ""
    @State private var showingEditCashAlert = false
    
    // Colors (matching Dashboard)
    private let bgDark = Color(hex: "#050816")
    private let cardBg = Color(hex: "#0B1220")
    private let positiveGreen = Color(hex: "#22C55E")
    private let negativeRed = Color(hex: "#EF4444")
    private let textSecondary = Color(hex: "#9CA3AF")
    
    var body: some View {
        NavigationView {
            ZStack {
                bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        InvestmentsHeader(
                            viewModel: viewModel,
                            showingAddPlatform: $showingAddPlatform,
                            showingAddInvestment: $showingAddInvestment,
                            isPrivateMode: isPrivateMode,
                            textSecondary: textSecondary,
                            positiveGreen: positiveGreen,
                            negativeRed: negativeRed
                        )
                        
                        // Platforms List
                        VStack(spacing: 16) {
                            ForEach($viewModel.platforms) { $platform in
                                PlatformCard(
                                    platform: $platform,
                                    viewModel: viewModel,
                                    cardBg: cardBg,
                                    isPrivateMode: isPrivateMode,
                                    textSecondary: textSecondary,
                                    positiveGreen: positiveGreen,
                                    negativeRed: negativeRed,
                                    onEdit: {
                                        platformToEdit = $platform.wrappedValue
                                    },
                                    onDelete: {
                                        platformToDelete = $platform.wrappedValue
                                        showingDeletePlatformAlert = true
                                    },
                                    onEditInvestment: { investment in
                                        editingPlatformId = $platform.id
                                        investmentToEdit = investment
                                    },
                                    onDeleteInvestment: { investment in
                                        editingPlatformId = $platform.id
                                        investmentToDelete = investment
                                        showingDeleteInvestmentAlert = true
                                    },
                                    onEditCash: {
                                        editingCashPlatformId = $platform.id
                                        editingCashValue = String(format: "%.2f", $platform.wrappedValue.cashBalance)
                                        showingEditCashAlert = true
                                    }
                                )

                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await viewModel.refreshPrices()
                }


                // Custom Toolbar Button
                
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddPlatform) {
                AddPlatformView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddInvestment) {
                AddInvestmentView(viewModel: viewModel)
            }
            .sheet(item: $platformToEdit) { platform in
                AddPlatformView(viewModel: viewModel, platformToEdit: platform)
            }
            .sheet(item: $investmentToEdit) { investment in
                AddInvestmentView(viewModel: viewModel, investmentToEdit: investment, editingPlatformId: editingPlatformId)
            }
            .alert("Delete Platform", isPresented: $showingDeletePlatformAlert, presenting: platformToDelete) { platform in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        viewModel.deletePlatform(id: platform.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { platform in
                Text("Are you sure you want to delete \(platform.name)? This action cannot be undone.")
            }
            .alert("Delete Investment", isPresented: $showingDeleteInvestmentAlert, presenting: investmentToDelete) { investment in
                Button("Delete", role: .destructive) {
                    if let platformId = editingPlatformId {
                        withAnimation {
                            viewModel.deleteInvestment(id: investment.id, from: platformId)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { investment in
                Text("Are you sure you want to delete \(investment.name)?")
            }
            .alert("Update Cash Balance", isPresented: $showingEditCashAlert) {
                TextField("Amount", text: $editingCashValue)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    if let amount = Double(editingCashValue), let id = editingCashPlatformId {
                        viewModel.updatePlatformCash(platformId: id, amount: amount)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter the new cash balance for this platform.")
            }
        }
    }
}

// MARK: - Subviews

struct InvestmentsHeader: View {
    @ObservedObject var viewModel: InvestmentsViewModel
    @Binding var showingAddPlatform: Bool
    @Binding var showingAddInvestment: Bool
    var isPrivateMode: Bool
    let textSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Portfolio Value")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(textSecondary)
                    
                    Text(viewModel.totalValue, format: .currency(code: "GBP").precision(.fractionLength(0)))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: 0)
                        .applyPrivacyBlur(isPrivateMode)
                    
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(viewModel.totalProfitLoss, format: .currency(code: "GBP").precision(.fractionLength(0)).sign(strategy: .always()))
                        Text("(\(viewModel.totalProfitLossPercent.formatted(.number.precision(.fractionLength(2))))%)")
                    }
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.totalProfitLoss >= 0 ? positiveGreen : negativeRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (viewModel.totalProfitLoss >= 0 ? positiveGreen : negativeRed).opacity(0.1)
                    )
                    .clipShape(Capsule())
                    .applyPrivacyBlur(isPrivateMode)
                }
                
                Spacer()
                
                Menu {
                    Button(action: { showingAddPlatform = true }) {
                        Label("Add Platform", systemImage: "folder.badge.plus")
                    }
                    
                    Button(action: { showingAddInvestment = true }) {
                        Label("Add Investment", systemImage: "chart.line.uptrend.xyaxis.circle")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                        .background(Color.white.opacity(0.1)) // Subtle background like dashboard icon
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

struct PlatformCard: View {
    @Binding var platform: InvestmentPlatform
    @ObservedObject var viewModel: InvestmentsViewModel
    let cardBg: Color
    var isPrivateMode: Bool
    let textSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onEditInvestment: (InvestmentPosition) -> Void
    let onDeleteInvestment: (InvestmentPosition) -> Void
    let onEditCash: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: platform.colorHex))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(platform.name)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Text(platform.totalValue, format: .currency(code: "GBP").precision(.fractionLength(0)))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(textSecondary)
                                    .applyPrivacyBlur(isPrivateMode)
                                
                                Text(platform.totalProfitLoss, format: .currency(code: "GBP").precision(.fractionLength(0)).sign(strategy: .always()))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(platform.totalProfitLoss >= 0 ? positiveGreen : negativeRed)
                                    .applyPrivacyBlur(isPrivateMode)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                }
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(cardBg)
            .contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Platform", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Platform", systemImage: "trash")
                }
            }
            
            // Investments List
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.05))
                    
                    ForEach(platform.investments) { investment in
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(investment.name)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.white)
                                    if let symbol = investment.symbol {
                                        Text(symbol)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(investment.currentValue, format: .currency(code: "GBP").precision(.fractionLength(0)))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                        .applyPrivacyBlur(isPrivateMode)
                                    
                                    Text(investment.profitLoss, format: .currency(code: "GBP").precision(.fractionLength(0)).sign(strategy: .always()))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(investment.profitLoss >= 0 ? positiveGreen : negativeRed)
                                        .applyPrivacyBlur(isPrivateMode)
                                }
                            }
                            .padding()
                            .contentShape(Rectangle()) // Make full row tappable for context menu
                            .contextMenu {
                                Button {
                                    onEditInvestment(investment)
                                } label: {
                                    Label("Edit Investment", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    onDeleteInvestment(investment)
                                } label: {
                                    Label("Delete Investment", systemImage: "trash")
                                }
                            }
                            
                            if investment.id != platform.investments.last?.id {
                                Divider().background(Color.white.opacity(0.05))
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    
                    // Cash Row (Always show for user to edit)
                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.leading, 16)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Cash")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(platform.cashBalance, format: .currency(code: "GBP"))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .applyPrivacyBlur(isPrivateMode)
                    }
                    .padding(16)
                    .contentShape(Rectangle()) // Make full row tappable
                    .contextMenu {
                        Button {
                            // Trigger edit
                            onEditCash()
                        } label: {
                            Label("Edit Cash", systemImage: "pencil")
                        }
                    }
                }
                .background(cardBg.opacity(0.5))
            }
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}


struct InvestmentRow: View {
    let investment: InvestmentPosition
    var isPrivateMode: Bool
    let textSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                if let symbol = investment.symbol {
                    Text(symbol)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(investment.currentValue, format: .currency(code: "GBP").precision(.fractionLength(0)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .applyPrivacyBlur(isPrivateMode)
                
                Text("\(investment.profitLoss >= 0 ? "+" : "")\(investment.profitLoss.formatted(.currency(code: "GBP").precision(.fractionLength(0))))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(investment.profitLoss >= 0 ? positiveGreen : negativeRed)
                    .applyPrivacyBlur(isPrivateMode)
            }
        }
        .padding(16)
    }
}


#Preview {
    InvestmentsView()
}
