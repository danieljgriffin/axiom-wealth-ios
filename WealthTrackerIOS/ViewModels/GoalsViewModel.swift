import Foundation
import SwiftUI
import Combine

class GoalsViewModel: ObservableObject {
    @Published var activeGoal: Goal?
    @Published var upcomingGoals: [Goal] = []
    @Published var completedGoals: [Goal] = []
    
    private let persistenceKey = "WealthTracker_Goals"
    
    init() {
        Task {
            await loadGoals()
        }
    }
    
    // MARK: - Actions
    
    private func generateTitle(amount: Double, date: Date) -> String {
        return "\(amount.formatted(.currency(code: "GBP").precision(.fractionLength(0)))) by \(date.formatted(.dateTime.month().year()))"
    }
    
    func setGoal(_ goal: Goal) {
        let titleToUse = goal.title.isEmpty ? generateTitle(amount: goal.targetAmount, date: goal.targetDate) : goal.title
        
        Task {
            do {
                _ = try await WealthService.shared.createGoal(
                    title: titleToUse,
                    targetAmount: goal.targetAmount, 
                    targetDate: goal.targetDate
                )
                await loadGoals()
            } catch {
                print("Failed to create goal: \(error)")
            }
        }
    }
    
    func updateActiveGoal(_ goal: Goal) {
        // Update local immediately for UI responsiveness
        var updatedGoal = goal
        if updatedGoal.title.isEmpty {
            updatedGoal.title = generateTitle(amount: goal.targetAmount, date: goal.targetDate)
        }
        activeGoal = updatedGoal
        
        Task {
            do {
                if let backendId = goal.backendId {
                    try await WealthService.shared.updateGoal(
                        id: backendId,
                        targetAmount: goal.targetAmount,
                        targetDate: goal.targetDate,
                        title: updatedGoal.title
                    )
                } else {
                    print("Cannot update goal without backend ID")
                }
                await loadGoals()
            } catch {
                print("Failed to update goal: \(error)")
            }
        }
    }
    
    func markActiveGoalAsCompleted() {
        guard var goal = activeGoal else { return }
        goal.isCompleted = true
        goal.completedDate = Date()
        
        // Optimistic Update
        completedGoals.insert(goal, at: 0)
        
        // Promote next upcoming to active
        if let next = upcomingGoals.first {
            activeGoal = next
            upcomingGoals.removeFirst()
        } else {
            activeGoal = nil
        }
        
        // Persist
        Task {
            do {
                if let backendId = goal.backendId {
                    try await WealthService.shared.updateGoal(
                        id: backendId,
                        isCompleted: true,
                        completedDate: goal.completedDate
                    )
                } else {
                    print("Goal has no backend ID, skipping persist")
                }
            } catch {
                print("Failed to save goal completion: \(error)")
                // In a real app, we might revert optimistic update here
            }
        }
    }
    
    func deleteActiveGoal() {
        // Todo: API Delete
        // Promote next upcoming
        if let next = upcomingGoals.first {
            activeGoal = next
            upcomingGoals.removeFirst()
        } else {
            activeGoal = nil
        }
    }
    
    func deleteCompletedGoal(_ goal: Goal) {
        // Todo: API Delete
        completedGoals.removeAll { $0.id == goal.id }
    }
    
    // MARK: - API
    
    @MainActor
    private func loadGoals() async {
        do {
            // Fetch goals and current net worth concurrently
            async let goalsTask = WealthService.shared.fetchGoals()
            async let summaryTask = WealthService.shared.fetchDashboardSummary()
            
            let (goals, summary) = try await (goalsTask, summaryTask)
            let currentNetWorth = summary.currentNetWorth
            
            // Logic to separate active/completed
            // 1. Explicitly Completed
            let explicitlyCompleted = goals.filter { $0.isCompleted }
            
            // 2. Mathematically Achieved (but not marked completed)
            let implicitlyAchieved = goals.filter { !$0.isCompleted && $0.targetAmount <= currentNetWorth }
            
            // 3. True Remaining Targets
            let incomplete = goals.filter { !$0.isCompleted && $0.targetAmount > currentNetWorth }.sorted { $0.targetDate < $1.targetDate }
            
            // Merge Completed & Achieved for History
            // We want latest first for history
            let allCompleted = (explicitlyCompleted + implicitlyAchieved).sorted { 
                ($0.completedDate ?? $0.targetDate) > ($1.completedDate ?? $1.targetDate) 
            }
            self.completedGoals = allCompleted
            
            // Pick first uncompleted as active (Current Focus)
            self.activeGoal = incomplete.first
            
            // The rest are upcoming
            if incomplete.count > 1 {
                self.upcomingGoals = Array(incomplete.dropFirst())
            } else {
                self.upcomingGoals = []
            }
            
        } catch {
            print("Error loading goals: \(error)")
        }
    }
}

// Private struct for easy encoding/decoding
private struct GoalsPersistenceData: Codable {
    let activeGoal: Goal?
    let completedGoals: [Goal]
}
