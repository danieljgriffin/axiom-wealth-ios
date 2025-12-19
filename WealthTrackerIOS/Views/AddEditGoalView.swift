import SwiftUI

struct AddEditGoalView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: GoalsViewModel
    
    var goalToEdit: Goal?
    
    @State private var targetAmount = ""
    @State private var targetDate = Date()
    
    private let bgDark = Color(hex: "#050816")
    private let cardBg = Color(hex: "#0B1220")
    
    var body: some View {
        NavigationView {
            ZStack {
                bgDark.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Goal Details").foregroundColor(.gray)) {
                        TextField("Target Amount (£)", text: $targetAmount)
                            .keyboardType(.decimalPad)
                        
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    }
                    .listRowBackground(cardBg)
                    .foregroundColor(.white)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(goalToEdit == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(targetAmount.isEmpty)
                    .foregroundColor(targetAmount.isEmpty ? .gray : .blue)
                }
            }
            .onAppear {
                if let goal = goalToEdit {
                    targetAmount = String(format: "%.2f", goal.targetAmount)
                    targetDate = goal.targetDate
                } else {
                    // Default target date to 1 year from now
                    targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let amount = Double(targetAmount) else { return }
        
        if var goal = goalToEdit {
            // Edit existing
            goal.targetAmount = amount
            goal.targetDate = targetDate
            viewModel.updateActiveGoal(goal)
        } else {
            // Create new
            let newGoal = Goal(
                id: UUID(),
                targetAmount: amount,
                targetDate: targetDate,
                isCompleted: false,
                completedDate: nil,
                createdAt: Date()
            )
            viewModel.setGoal(newGoal)
        }
        dismiss()
    }
}
