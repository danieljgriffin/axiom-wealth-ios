import SwiftUI

struct Trading212ConnectView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var shouldDismissParent: Bool
    @ObservedObject var viewModel: InvestmentsViewModel
    
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let bgDark = Color(hex: "#050816")
    private let cardBg = Color(hex: "#0B1220")
    private let textSecondary = Color(hex: "#9CA3AF")
    
    var body: some View {
        ZStack {
            bgDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Logo & Header
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/9/96/Trading_212_icon.png")) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color(hex: "#3B82F6"))
                                    .frame(width: 80, height: 80)
                                    .overlay(ProgressView().tint(.white))
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            case .failure:
                                Circle()
                                    .fill(Color(hex: "#3B82F6"))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text("212")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .shadow(color: Color(hex: "#3B82F6").opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        Text("Connect Trading 212")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Import your portfolio automatically")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(textSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Instructions Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to get your API Key")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InstructionRow(number: "1", text: "Open the Trading 212 app")
                            InstructionRow(number: "2", text: "Go to Menu > Settings > API")
                            InstructionRow(number: "3", text: "Tap 'Generate API Key'")
                            InstructionRow(number: "4", text: "Name your key (e.g. WealthTracker)")
                            InstructionRow(number: "5", text: "Select: Account Data, History, Orders, Portfolio")
                            InstructionRow(number: "6", text: "Uncheck all other permissions")
                            InstructionRow(number: "7", text: "Copy the API Key ID and Secret Key")
                        }
                    }
                    .padding(20)
                    .background(cardBg)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API KEY ID")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(textSecondary)
                                .tracking(1)
                            
                            TextField("Paste your API Key ID here", text: $apiKey)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SECRET KEY")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(textSecondary)
                                .tracking(1)
                            
                            SecureField("Paste your Secret Key here", text: $apiSecret)
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            
            if viewModel.isLoading {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                .tint(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Connect") {
                    connect()
                }
                .fontWeight(.bold)
                .foregroundColor((apiKey.isEmpty || apiSecret.isEmpty) ? textSecondary : Color(hex: "#3B82F6"))
                .disabled(apiKey.isEmpty || apiSecret.isEmpty || viewModel.isLoading)
            }
        }
        .alert("Connection Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func connect() {
        Task {
            do {
                try await viewModel.addTrading212Platform(apiKey: apiKey, apiSecret: apiSecret)
                shouldDismissParent = true // Signal parent to dismiss
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(number)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color(hex: "#9CA3AF")) // textSecondary
                .fixedSize(horizontal: false, vertical: true) // Allow text to wrap
        }
    }
}
