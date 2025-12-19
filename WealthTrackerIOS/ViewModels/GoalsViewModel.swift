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
    
    func setGoal(_ goal: Goal) {
        // Todo: API Create/Update
        activeGoal = goal
        // Re-sort
        Task { await loadGoals() }
    }
    
    func updateActiveGoal(_ goal: Goal) {
        // Todo: API Update
        activeGoal = goal
        Task { await loadGoals() }
    }
    
    func markActiveGoalAsCompleted() {
        // Todo: API Update status
        guard var goal = activeGoal else { return }
        goal.isCompleted = true
        goal.completedDate = Date()
        
        // Move to completed locally
        completedGoals.insert(goal, at: 0)
        
        // Promote next upcoming to active
        if let next = upcomingGoals.first {
            activeGoal = next
            upcomingGoals.removeFirst()
        } else {
            activeGoal = nil
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
            let goals = try await WealthService.shared.fetchGoals()
            
            // Logic to separate active/completed
            let completed = goals.filter { $0.isCompleted }
            let incomplete = goals.filter { !$0.isCompleted }.sorted { $0.targetDate < $1.targetDate }
            
            self.completedGoals = completed.sorted { ($0.completedDate ?? $0.targetDate) > ($1.completedDate ?? $1.targetDate) }
            
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
