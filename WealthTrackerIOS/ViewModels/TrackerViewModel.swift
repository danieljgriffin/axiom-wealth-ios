import Foundation
import Combine

@MainActor
final class TrackerViewModel: ObservableObject {
    @Published var selectedYear: Int
    @Published private(set) var currentYear: Int
    @Published private(set) var snapshots: [TrackerSnapshot] = []
    @Published private(set) var incomeRows: [APIIncomeData] = []
    @Published private(set) var currentNetWorth: Double?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var error: String?

    init() {
        let year = TrackerService.calendar.component(.year, from: Date())
        currentYear = year
        selectedYear = year
    }

    var years: [Int] {
        Set(snapshots.map(\.year) + incomeRows.compactMap { Int($0.year) } + [currentYear])
            .sorted(by: >)
    }

    var yearSnapshots: [TrackerSnapshot] {
        snapshots.filter { $0.year == selectedYear }
    }

    var yearIncome: APIIncomeData? {
        incomeRows.first { $0.year == String(selectedYear) }
    }

    var yearlyChange: Double? {
        guard let opening = yearSnapshots.first(where: { $0.monthNumber == 1 })?.totalNetWorth,
              opening > 0 else { return nil }
        let end = selectedYear == currentYear ? currentNetWorth : yearSnapshots.first?.totalNetWorth
        return end.map { ($0 - opening) / opening }
    }

    func monthlyChange(for snapshot: TrackerSnapshot) -> Double? {
        guard let previous = previousSnapshot(for: snapshot), previous.totalNetWorth > 0 else { return nil }
        return (snapshot.totalNetWorth - previous.totalNetWorth) / previous.totalNetWorth
    }

    func platformChange(for name: String, in snapshot: TrackerSnapshot) -> (amount: Double, percent: Double?)? {
        guard let current = snapshot.platformBreakdown[name],
              let previous = previousSnapshot(for: snapshot)?.platformBreakdown[name] else { return nil }
        let amount = current - previous
        return (amount, previous == 0 ? nil : amount / previous)
    }

    private func previousSnapshot(for snapshot: TrackerSnapshot) -> TrackerSnapshot? {
        let previousYear = snapshot.monthNumber == 1 ? snapshot.year - 1 : snapshot.year
        let previousMonth = snapshot.monthNumber == 1 ? 12 : snapshot.monthNumber - 1
        return snapshots.first {
            $0.year == previousYear && $0.monthNumber == previousMonth
        }
    }

    func load() async {
        guard !isLoading else { return }
        let year = TrackerService.calendar.component(.year, from: Date())
        if selectedYear == currentYear { selectedYear = year }
        currentYear = year
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let snapshotRequest = TrackerService.snapshots()
            async let incomeRequest = TrackerService.incomeTotals()
            async let netWorthRequest = TrackerService.netWorth()
            let (history, totals, netWorth) = try await (snapshotRequest, incomeRequest, netWorthRequest)
            try Task.checkCancellation()
            snapshots = history.filter { $0.monthNumber > 0 }.sorted {
                ($0.year, $0.monthNumber) > ($1.year, $1.monthNumber)
            }
            incomeRows = totals.sorted { $0.year > $1.year }
            currentNetWorth = netWorth.total_networth
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            #if DEBUG && targetEnvironment(simulator)
            self.error = "Couldn’t load Tracker. Check that the local Tracker server is running and try again."
            #else
            self.error = "Couldn’t load Tracker. Check your connection and try again."
            #endif
        }
    }
}
