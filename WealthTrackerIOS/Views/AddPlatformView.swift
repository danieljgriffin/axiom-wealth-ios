import SwiftUI

struct AddPlatformView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: InvestmentsViewModel
    var platformToEdit: InvestmentPlatform?
    
    @State private var name = ""
    @State private var selectedColor = "#22C55E"
    
    @State private var shouldDismiss = false
    
    let colors = [
        "#EF4444", // Red
        "#F97316", // Orange
        "#F59E0B", // Amber
        "#84CC16", // Lime
        "#10B981", // Emerald
        "#06B6D4", // Cyan
        "#3B82F6", // Blue
        "#6366F1", // Indigo
        "#8B5CF6", // Violet
        "#D946EF", // Fuchsia
        "#EC4899", // Pink
        "#F43F5E", // Rose
        "#9CA3AF", // Gray
        "#64748B", // Slate
        "#71717A", // Zinc
        "#78350F", // Brown
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.bgDark.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if platformToEdit == nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Connect Automatically")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            NavigationLink(destination: Trading212ConnectView(shouldDismissParent: $shouldDismiss, viewModel: viewModel)) {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: "#3B82F6"))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text("212")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text("Connect Trading 212")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.cardBg)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Platform Details")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 16) {
                            TextField("Platform Name", text: $name)
                                .padding()
                                .background(Color.cardBg)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 44))
                            ], spacing: 12) {
                                ForEach(colors, id: \.self) { color in
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                }
                .onAppear {
                    if let platform = platformToEdit {
                        name = platform.name
                        selectedColor = platform.colorHex
                    }
                }
                .onChange(of: shouldDismiss) { _, dismiss in
                    if dismiss {
                        self.dismiss()
                    }
                }

            .navigationTitle(platformToEdit == nil ? "Add Platform" : "Edit Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(platformToEdit == nil ? "Add" : "Save") {
                        if let platform = platformToEdit {
                            var updatedPlatform = platform
                            updatedPlatform.name = name
                            updatedPlatform.colorHex = selectedColor
                            viewModel.updatePlatform(updatedPlatform)
                        } else {
                            viewModel.addPlatform(name: name, colorHex: selectedColor)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? .gray : .blue)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
