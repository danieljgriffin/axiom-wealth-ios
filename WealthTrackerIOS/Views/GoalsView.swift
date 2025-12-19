import SwiftUI

struct GoalsView: View {
    @ObservedObject var viewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal?
    @State private var selectedTab = 0
    
    private let bgDark = Color(hex: "#050816")
    private let cardBg = Color(hex: "#0B1220")
    private let textSecondary = Color(hex: "#9CA3AF")
    private let positiveGreen = Color(hex: "#22C55E")
    
    // We need the current net worth to calculate progress
    var currentNetWorth: Double
    
    init(viewModel: GoalsViewModel, currentNetWorth: Double) {
        self.viewModel = viewModel
        self.currentNetWorth = currentNetWorth
        
        // Custom Segmented Control Appearance for Dark Mode
        let appearance = UISegmentedControl.appearance()
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
        appearance.backgroundColor = UIColor(Color(hex: "#0B1220")) // Card BG
        appearance.selectedSegmentTintColor = UIColor(Color(hex: "#22C55E")) // Green
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                bgDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Picker
                    Picker("View", selection: $selectedTab) {
                        Text("Active").tag(0)
                        Text("History").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(bgDark) // Sticky-ish feel if we were pinned, but fine here
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
                                // MARK: - Active Tab
                                
                                // Active Goal Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Current Focus")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    if let goal = viewModel.activeGoal {
                                        ActiveGoalCard(
                                            goal: goal,
                                            currentNetWorth: currentNetWorth,
                                            cardBg: cardBg,
                                            textSecondary: textSecondary,
                                            positiveGreen: positiveGreen,
                                            onEdit: { editingGoal = goal },
                                            onComplete: { viewModel.markActiveGoalAsCompleted() },
                                            onDelete: { viewModel.deleteActiveGoal() }
                                        )
                                    } else if viewModel.upcomingGoals.isEmpty {
                                        // Only show empty state if no upcoming either (truly empty)
                                        EmptyGoalCard(cardBg: cardBg, textSecondary: textSecondary) {
                                            showingAddGoal = true
                                        }
                                    } else {
                                        // No active goal but have upcoming? Promote logic handled in VM, 
                                        // but if we are here, something weird or waiting for next sort.
                                        // Show placeholder.
                                        Text("No Active Goal Selected")
                                            .foregroundColor(textSecondary)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Upcoming Goals Section
                                if !viewModel.upcomingGoals.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Upcoming Goals")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        ForEach(viewModel.upcomingGoals) { goal in
                                            UpcomingGoalCard(
                                                goal: goal,
                                                cardBg: cardBg,
                                                textSecondary: textSecondary,
                                                onEdit: { editingGoal = goal }
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                            } else {
                                // MARK: - History Tab
                                
                                if !viewModel.completedGoals.isEmpty {
                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(viewModel.completedGoals) { goal in
                                            CompletedGoalRow(goal: goal, cardBg: cardBg, textSecondary: textSecondary)
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        viewModel.deleteCompletedGoal(goal)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                } else {
                                    VStack(spacing: 16) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 40))
                                            .foregroundColor(textSecondary)
                                        Text("No completed goals yet")
                                            .foregroundColor(textSecondary)
                                    }
                                    .padding(.top, 40)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddEditGoalView(viewModel: viewModel)
            }
            .sheet(item: $editingGoal) { goal in
                AddEditGoalView(viewModel: viewModel, goalToEdit: goal)
            }
        }
    }
}

struct ActiveGoalCard: View {
    let goal: Goal
    let currentNetWorth: Double
    let cardBg: Color
    let textSecondary: Color
    let positiveGreen: Color
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    // Add negativeRed
    private let negativeRed = Color(hex: "#EF4444")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Goal")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("\(goal.targetAmount.formatted(.currency(code: "GBP").precision(.fractionLength(0)))) by \(goal.targetDate.formatted(.dateTime.month().year()))")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(textSecondary)
                }
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: onComplete) {
                        Label("Mark Completed", systemImage: "checkmark.circle")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(textSecondary)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            
            // Progress Bar or Completion Button
            let progress = goal.progress(currentAmount: currentNetWorth)
            
            if progress >= 1.0 {
                Button(action: {
                    // Haptic Feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onComplete()
                }) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Mark as Done")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#22C55E"))
                    .cornerRadius(12)
                }
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text(progress.formatted(.percent.precision(.fractionLength(1))))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(colors: [Color(hex: "#22D3EE"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geometry.size.width * progress, height: 12)
                        }
                    }
                    .frame(height: 12)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("REMAINING")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(textSecondary)
                    Text((max(goal.targetAmount - currentNetWorth, 0)).formatted(.currency(code: "GBP").precision(.fractionLength(0))))
                        .font(.body)
                        .foregroundColor(.white)
                }
                Spacer()
                
                let days = goal.daysRemaining()
                VStack(alignment: .trailing) {
                    Text(days < 0 ? "DAYS OVERDUE" : "DAYS LEFT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(days < 0 ? negativeRed : textSecondary)
                    Text("\(abs(days))")
                        .font(.body)
                        .foregroundColor(days < 0 ? negativeRed : .white)
                }
            }
        }
        .padding(20)
        .background(cardBg)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct EmptyGoalCard: View {
    let cardBg: Color
    let textSecondary: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                Text("Set a Goal")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Track your progress towards financial freedom")
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .background(cardBg)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(Color.white.opacity(0.1))
            )
        }
    }
}

struct CompletedGoalRow: View {
    let goal: Goal
    let cardBg: Color
    let textSecondary: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Goal: \(goal.targetAmount.formatted(.currency(code: "GBP").precision(.fractionLength(0))))")
                    .font(.body)
                    .foregroundColor(.white)
                
                if let completedDate = goal.completedDate {
                    Text("Achieved \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                } else {
                    // Implicitly achieved, so show target date context
                    Text("Target: \(goal.targetDate.formatted(.dateTime.month().year()))")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(hex: "#22C55E"))
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
    }
}

struct UpcomingGoalCard: View {
    let goal: Goal
    let cardBg: Color
    let textSecondary: Color
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Target")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(textSecondary)
                    .textCase(.uppercase)
                
                Text(goal.targetAmount.formatted(.currency(code: "GBP").precision(.fractionLength(0))))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                    Text(goal.targetDate.formatted(.dateTime.month().year()))
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textSecondary)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(20)
        .background(cardBg)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

