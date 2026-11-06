import SwiftUI

struct TrackerView: View {
    private enum Section: String, CaseIterable {
        case netWorth = "Net worth"
        case income = "Income & investing"
    }

    var onSave: () -> Void
    @EnvironmentObject private var investments: InvestmentsViewModel
    @StateObject private var model = TrackerViewModel()
    @State private var section = Section.netWorth
    @State private var recording = false
    @State private var editingTotals = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    trackerHeader

                    Picker("Tracker section", selection: $section) {
                        ForEach(Section.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let error = model.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).font(.subheadline)
                            Button("Try again") { Task { await model.load() } }
                        }
                        .padding()
                        .trackerCard()
                    }

                    if model.hasLoaded {
                        switch section {
                        case .netWorth: netWorth
                        case .income: income
                        }
                    } else if model.error == nil {
                        ProgressView("Loading Tracker…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 8)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(TrackerStyle.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.load() }
            .task { await model.load() }
            .sheet(isPresented: $recording) {
                RecordTrackerActivityView(platforms: activityPlatforms, onSave: refreshAfterSave)
            }
            .sheet(isPresented: $editingTotals) {
                EditTrackerTotalsView(
                    year: model.selectedYear,
                    currentYear: model.currentYear,
                    totals: model.yearIncome,
                    onSave: refreshAfterSave
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var trackerHeader: some View {
        HStack {
            Text("Tracker")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Menu {
                Picker("Year", selection: $model.selectedYear) {
                    ForEach(model.years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(String(model.selectedYear)).monospacedDigit()
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(TrackerStyle.card, in: Capsule())
            }
            .tint(.primary)
            .accessibilityLabel("Year \(String(model.selectedYear))")
        }
    }

    private var netWorth: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.selectedYear == model.currentYear ? "Year-to-date net worth change" : "Net worth change")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let change = model.yearlyChange {
                    TrackerChange(value: change)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                } else {
                    Text("—").font(.largeTitle)
                }
                Text(model.selectedYear == model.currentYear ? "Since the January opening snapshot" : "January to the last saved snapshot")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .trackerCard()

            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly snapshots").font(.headline)
                Text("Opening balances by month. Tap to see the accounts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityAddTraits(.isHeader)

            if model.yearSnapshots.isEmpty {
                Text("No saved net worth snapshots for \(String(model.selectedYear)).")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.yearSnapshots) { snapshot in
                        NavigationLink {
                            snapshotDetail(snapshot)
                        } label: {
                            HStack(spacing: 12) {
                                Text(snapshot.displayDate)
                                    .font(.headline)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    TrackerAmount(value: snapshot.totalNetWorth).font(.headline)
                                    if let change = model.monthlyChange(for: snapshot) {
                                        TrackerChange(value: change)
                                            .font(.footnote)
                                            .accessibilityHint("Compared with the previous month’s opening balance")
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if snapshot.id != model.yearSnapshots.last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
                .trackerCard()
            }
        }
    }

    private var income: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Income & investing").font(.headline)
                Spacer()
                Menu("Income options", systemImage: "ellipsis.circle") {
                    Button("Edit totals", systemImage: "pencil") { editingTotals = true }
                }
                .labelStyle(.iconOnly)
                .disabled(model.isLoading)
            }
            if let totals = model.yearIncome {
                TrackerIncomeCard(totals: totals)
            } else {
                Text("No income or investment totals recorded for \(String(model.selectedYear)).")
                    .foregroundStyle(.secondary)
            }

            Button {
                recording = true
            } label: {
                Label("Record activity", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)

            NavigationLink {
                allYears
            } label: {
                HStack {
                    Label("All years", systemImage: "calendar")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
                .padding()
                .trackerCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var allYears: some View {
        let total = APIIncomeData(
            year: "Total",
            income: model.incomeRows.reduce(0) { $0 + $1.income },
            investment: model.incomeRows.reduce(0) { $0 + $1.investment }
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TrackerIncomeCard(totals: total, title: "Combined totals")
                ForEach(model.incomeRows, id: \.year) { row in
                    TrackerIncomeCard(totals: row, title: row.year)
                }
            }
            .padding()
        }
        .background(TrackerStyle.background.ignoresSafeArea())
        .navigationTitle("All years")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func snapshotDetail(_ snapshot: TrackerSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Opening net worth").font(.subheadline).foregroundStyle(.secondary)
                    TrackerAmount(value: snapshot.totalNetWorth).font(.largeTitle.bold())
                    if let change = model.monthlyChange(for: snapshot) {
                        HStack {
                            Text("Since previous month’s opening").font(.footnote).foregroundStyle(.secondary)
                            TrackerChange(value: change).font(.footnote)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .trackerCard()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Platform balances").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("Changes from the previous month’s opening balance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(sortedPlatforms(Array(snapshot.platformBreakdown.keys)), id: \.self) { name in
                        NavigationLink {
                            platformHistory(name, year: snapshot.year)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(platformColor(name))
                                    .frame(width: 9, height: 9)
                                    .accessibilityHidden(true)
                                Text(name)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let value = snapshot.platformBreakdown[name] {
                                        TrackerAmount(value: value, showPence: true).font(.subheadline.weight(.semibold))
                                    }
                                    if let change = model.platformChange(for: name, in: snapshot) {
                                        TrackerBalanceChange(amount: change.amount, percent: change.percent)
                                    } else {
                                        Text("—")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .accessibilityLabel("No previous month’s balance")
                                    }
                                }
                                .layoutPriority(1)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .trackerCard()
            }
            .padding()
        }
        .background(TrackerStyle.background.ignoresSafeArea())
        .navigationTitle("\(snapshot.displayDate) \(String(snapshot.year))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func platformHistory(_ name: String, year: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(String(year)) monthly opening balances")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(model.snapshots.filter { $0.year == year }) { snapshot in
                        HStack {
                            Text(snapshot.displayDate)
                            Spacer()
                            if let value = snapshot.platformBreakdown[name] {
                                TrackerAmount(value: value)
                            } else {
                                Text("—").foregroundStyle(.secondary)
                                    .accessibilityLabel("No recorded balance")
                            }
                        }
                        .padding()
                    }
                }
                .trackerCard()
            }
            .padding()
        }
        .background(TrackerStyle.background.ignoresSafeArea())
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var activityPlatforms: [String] {
        sortedPlatforms(investments.platforms.map(\.name).filter { !isCash($0) })
    }

    private func isCash(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "cash"
    }

    private func sortedPlatforms(_ names: [String]) -> [String] {
        names.sorted {
            if isCash($0) != isCash($1) { return !isCash($0) }
            return $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private func platformColor(_ name: String) -> Color {
        investments.platforms.first { $0.name == name }.map { Color(hex: $0.colorHex) } ?? .secondary
    }

    private func refreshAfterSave() async {
        onSave()
        await model.load()
    }
}

enum TrackerStyle {
    static let background = Color(hex: "#050816")
    static let card = Color(hex: "#0B1220")
    static let money = FloatingPointFormatStyle<Double>.Currency(code: "GBP")
        .precision(.fractionLength(0...2))
}

private extension View {
    func trackerCard() -> some View {
        background(TrackerStyle.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TrackerIncomeCard: View {
    let totals: APIIncomeData
    var title: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.headline).accessibilityAddTraits(.isHeader) }
            HStack {
                Text("Take-home income")
                Spacer()
                TrackerAmount(value: totals.income).fontWeight(.semibold)
            }
            HStack {
                Text("Invested")
                Spacer()
                TrackerAmount(value: totals.investment).fontWeight(.semibold)
            }
            HStack {
                Text("% invested")
                Spacer()
                TrackerChange(value: totals.income > 0 ? totals.investment / totals.income : 0, signed: false)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .trackerCard()
    }
}

private struct TrackerAmount: View {
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    let value: Double
    var showPence = false

    var body: some View {
        let format = showPence ? TrackerStyle.money.precision(.fractionLength(2)) : TrackerStyle.money
        let money = value.formatted(format)
        Text(isPrivateMode ? "••••" : money)
            .monospacedDigit()
            .accessibilityLabel(isPrivateMode ? "Hidden amount" : money)
    }
}

private struct TrackerChange: View {
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    let value: Double
    var signed = true

    var body: some View {
        let percent = value.formatted(.percent.precision(.fractionLength(1))
            .sign(strategy: signed ? .always(includingZero: false) : .automatic))
        Text(isPrivateMode ? "••••" : percent)
            .monospacedDigit()
            .foregroundStyle(isPrivateMode || value == 0 ? Color.secondary : (value > 0 ? .green : .red))
            .accessibilityLabel(isPrivateMode ? "Hidden percentage" : percent)
    }
}

private struct TrackerBalanceChange: View {
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    let amount: Double
    let percent: Double?

    var body: some View {
        let money = amount.formatted(TrackerStyle.money.precision(.fractionLength(2))
            .sign(strategy: amount == 0 ? .automatic : .always()))
        let percentage = percent.map {
            $0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
        }
        let change = percentage.map { "\(money) (\($0))" } ?? money
        Text(isPrivateMode ? "••••" : change)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(isPrivateMode || amount == 0 ? Color.secondary : (amount > 0 ? .green : .red))
            .accessibilityLabel(isPrivateMode ? "Hidden change" : change)
    }
}
