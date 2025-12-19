import Foundation

struct Goal: Identifiable, Codable, Equatable {
    let id: UUID
    var targetAmount: Double
    var targetDate: Date
    var isCompleted: Bool
    var completedDate: Date?
    var createdAt: Date
    
    // Computed helpers
    func progress(currentAmount: Double) -> Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1.0)
    }
    
    func daysRemaining() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return max(components.day ?? 0, 0)
    }
    
    static var empty: Goal {
        Goal(
            id: UUID(),
            targetAmount: 0,
            targetDate: Date(),
            isCompleted: false,
            completedDate: nil,
            createdAt: Date()
        )
    }
}
