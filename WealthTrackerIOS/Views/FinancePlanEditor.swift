import SwiftUI

struct FinancePlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    let section: FinancePlanSection
    let initial: FinancePlan
    let onSave: (FinancePlan) -> Void

    @State private var pay: String
    @State private var bills: [DraftBill]
    @State private var allocations: [DraftAllocation]
    @State private var accounts: [String: [APIInvestment]] = [:]
    @State private var accountsLoading = false
    @State private var accountsError = false
    @State private var search: FundSearch?
    @State private var saving = false
    @State private var error: String?

    init(section: FinancePlanSection, initial: FinancePlan, onSave: @escaping (FinancePlan) -> Void) {
        self.section = section
        self.initial = initial
        self.onSave = onSave
        _pay = State(initialValue: Self.entryAmount(initial.take_home_monthly_pence))
        _bills = State(initialValue: initial.bills.map {
            DraftBill(name: $0.name, amount: Self.entryAmount($0.amount_pence), frequency: $0.frequency)
        })
        _allocations = State(initialValue: initial.allocations.map { row in
            DraftAllocation(platform: row.platform, amount: Self.entryAmount(row.amount_pence), funds: row.funds.map {
                DraftFund(name: $0.name, amount: Self.entryAmount($0.amount_pence), instrument: $0.instrument)
            })
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Free to spend") {
                    let annual = (try? updatedPlan()).map { Double($0.annualFree) }
                    FinancePeriodAmounts(annualPence: annual, color: (annual ?? 0) < 0 ? .red : .green, prominent: true)
                }

                Group {
                    switch section {
                    case .pay:
                        Section("Take-home pay") {
                            FinancePlanEntryField(label: "Monthly take-home pay (£)", text: $pay)
                        }
                    case .bills:
                        billFields
                    case .investments:
                        investmentFields
                    }
                }
                .disabled(saving)

                Section {
                    Button(saving ? "Saving…" : "Save plan", action: beginSave)
                        .fontWeight(.semibold)
                        .disabled(saving)
                    Button("Cancel", role: .cancel) { dismiss() }.disabled(saving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TrackerStyle.background.ignoresSafeArea())
            .navigationTitle(section.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save plan", action: beginSave).disabled(saving)
                }
            }
            .task { if section == .investments { await loadAccounts() } }
            .sheet(item: $search) { context in
                FinancePlanFundSearch(query: context.query, holdings: accounts[context.platform] ?? []) { result in
                    guard let row = allocations.firstIndex(where: { $0.id == context.allocation }),
                          let item = allocations[row].funds.firstIndex(where: { $0.id == context.id }) else { return }
                    allocations[row].funds[item].name = result.name
                    allocations[row].funds[item].instrument = result.instrument
                }
            }
            .alert("Couldn’t save the plan", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
        .interactiveDismissDisabled(saving)
    }

    @ViewBuilder private var billFields: some View {
        ForEach($bills) { $bill in
            Section(bill.name.isEmpty ? "New bill" : bill.name) {
                TextField("Bill name", text: $bill.name)
                FinancePlanEntryField(label: "Amount (£)", text: $bill.amount)
                Picker("Frequency", selection: $bill.frequency) {
                    ForEach(FinancePlan.Bill.Frequency.allCases, id: \.self) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                Button("Remove bill", role: .destructive) { bills.removeAll { $0.id == bill.id } }
            }
        }
        Section {
            Button("Add bill", systemImage: "plus") { bills.append(DraftBill()) }
                .disabled(bills.count >= 100)
        }
    }

    @ViewBuilder private var investmentFields: some View {
        if accountsLoading {
            Section { ProgressView("Loading Portfolio accounts…") }
        } else if accountsError {
            Section {
                Text("Couldn’t load Portfolio accounts.").foregroundStyle(.secondary)
                Button("Try again") { Task { await loadAccounts() } }
            }
        }

        ForEach($allocations) { $row in
            Section(row.platform.isEmpty ? "New platform" : row.platform) {
                Picker("Platform", selection: $row.platform) {
                    Text("Select a Portfolio account").tag("")
                    if !row.platform.isEmpty && accounts[row.platform] == nil {
                        Text(accountsLoading || accountsError ? row.platform : "\(row.platform) (saved in plan)").tag(row.platform)
                    }
                    ForEach(platformOptions(current: row.platform), id: \.self) { platform in
                        Text(platform).tag(platform)
                    }
                }
                .pickerStyle(.menu)
                FinancePlanEntryField(label: "Monthly platform total (£)", text: $row.amount)
                DisclosureGroup("Investments (\(row.funds.count))") {
                    ForEach($row.funds) { $fund in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Investment name", text: Binding(get: { fund.name }, set: { name in
                                fund.name = name
                                fund.instrument = nil
                            }))
                            if let instrument = fund.instrument {
                                Label("Linked · \(instrument.displayIdentifier)", systemImage: "link")
                                    .font(.caption).foregroundStyle(.green)
                            }
                            FinancePlanEntryField(label: "Monthly amount (£)", text: $fund.amount)
                            Button("Find investment", systemImage: "magnifyingglass") { openSearch(fund, in: row) }
                                .font(.subheadline.weight(.semibold))
                            Button("Remove investment", role: .destructive) { row.funds.removeAll { $0.id == fund.id } }
                                .font(.footnote)
                        }
                        .padding(.vertical, 4)
                        .buttonStyle(.borderless)
                    }
                    Button("Add investment", systemImage: "plus") {
                        let fund = DraftFund()
                        row.funds.append(fund)
                        openSearch(fund, in: row)
                    }
                    .disabled(row.funds.count >= 100)
                }
                Button("Remove platform", role: .destructive) { allocations.removeAll { $0.id == row.id } }
            }
        }
        Section {
            Button("Add platform", systemImage: "plus") { allocations.append(DraftAllocation()) }
                .disabled(allocations.count >= 100 || allocations.contains { $0.platform.isEmpty } || platformOptions(current: "").isEmpty)
        }
    }

    private func platformOptions(current: String) -> [String] {
        let selected = Set(allocations.map(\.platform))
        return accounts.keys.filter { $0 == current || !selected.contains($0) }.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func openSearch(_ fund: DraftFund, in row: DraftAllocation) {
        search = FundSearch(id: fund.id, allocation: row.id, platform: row.platform, query: fund.instrument?.symbol ?? fund.name)
    }

    private func loadAccounts() async {
        accountsLoading = true
        defer { accountsLoading = false }
        do {
            accounts = try await FinancePlanService.accounts()
            accountsError = false
        } catch {
            if !Task.isCancelled { accountsError = true }
        }
    }

    private func beginSave() {
        guard !saving else { return }
        do {
            let draft = try updatedPlan()
            saving = true
            Task {
                defer { saving = false }
                do {
                    let saved = try await FinancePlanService.save(draft, section: section, fallback: initial)
                    onSave(saved)
                    dismiss()
                } catch {
                    self.error = "Try again. Your edits are still here."
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updatedPlan() throws -> FinancePlan {
        var draft = initial
        switch section {
        case .pay:
            draft.take_home_monthly_pence = try pence(pay)
        case .bills:
            draft.bills = try bills.map { bill in
                FinancePlan.Bill(name: try validName(bill.name), amount_pence: try pence(bill.amount), frequency: bill.frequency)
            }
        case .investments:
            let platforms = allocations.map { $0.platform.lowercased() }
            guard !platforms.contains(""), Set(platforms).count == platforms.count else {
                throw ValidationError(message: "Choose a different Portfolio account for each platform.")
            }
            draft.allocations = try allocations.map { row in
                FinancePlan.Allocation(platform: row.platform, amount_pence: try pence(row.amount), funds: try row.funds.map {
                    FinancePlan.Fund(name: try validName($0.name), amount_pence: try pence($0.amount), instrument: $0.instrument)
                })
            }
        }
        return draft
    }

    private func pence(_ input: String) throws -> Int {
        let value = financePlanDecimalText(input)
        guard value.range(of: #"^(?:[0-9]+(?:\.[0-9]{0,2})?|\.[0-9]{1,2})$"#, options: .regularExpression) != nil,
              let pounds = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")),
              pounds <= 100_000_000 else {
            throw ValidationError(message: "Enter each amount in pounds, with up to two decimal places.")
        }
        return NSDecimalNumber(decimal: pounds * 100).intValue
    }

    private func validName(_ input: String) throws -> String {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200 else { throw ValidationError(message: "Enter a name for each bill or investment.") }
        return name
    }

    private static func entryAmount(_ pence: Int) -> String {
        (Decimal(pence) / 100).formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    private struct DraftBill: Identifiable {
        let id = UUID()
        var name = ""
        var amount = "0"
        var frequency = FinancePlan.Bill.Frequency.monthly
    }

    private struct DraftFund: Identifiable {
        let id = UUID()
        var name = ""
        var amount = "0"
        var instrument: PlanInstrument?
    }

    private struct DraftAllocation: Identifiable {
        let id = UUID()
        var platform = ""
        var amount = "0"
        var funds: [DraftFund] = []
    }

    private struct FundSearch: Identifiable {
        let id: UUID
        let allocation: UUID
        let platform: String
        let query: String
    }

    private struct ValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}

func financePlanDecimalText(_ input: String) -> String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
}

struct FinancePlanEntryField: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let label: String
    var placeholder = "0.00"
    @Binding var text: String

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        layout {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                .monospacedDigit()
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 100)
                .accessibilityLabel(label)
        }
    }
}

private struct FinancePlanFundSearch: View {
    @Environment(\.dismiss) private var dismiss
    @State var query: String
    let holdings: [APIInvestment]
    let onSelect: (PlanSearchResult) -> Void

    @State private var results: [PlanSearchResult] = []
    @State private var completedTerm = ""
    @State private var error = false

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matches: [PlanSearchResult] { completedTerm == term ? results : [] }

    var body: some View {
        let bySymbol = Dictionary(matches.map { ($0.instrument.symbol.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let words = term.lowercased().split { !$0.isLetter && !$0.isNumber }
        let owned = holdings.compactMap { holding -> PlanSearchResult? in
            guard let symbol = holding.symbol, !symbol.isEmpty else { return nil }
            if let match = bySymbol[symbol.uppercased()] { return match }
            let text = "\(holding.name) \(symbol)".lowercased()
            guard words.allSatisfy({ text.contains($0) }) else { return nil }
            let isin = symbol.range(of: #"^[A-Z]{2}[A-Z0-9]{9}[0-9]$"#, options: .regularExpression) != nil ? symbol : nil
            return PlanSearchResult(name: holding.name, instrument: PlanInstrument(symbol: symbol, isin: isin))
        }
        let heldSymbols = Set(owned.map { $0.instrument.symbol.uppercased() })
        let market = matches.filter { !heldSymbols.contains($0.instrument.symbol.uppercased()) }

        NavigationStack {
            List {
                Section {
                    TextField("Name, ticker or ISIN", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Search investments")
                }
                if !owned.isEmpty {
                    Section("Held on this account") {
                        ForEach(Array(owned.enumerated()), id: \.offset) { _, result in searchRow(result) }
                    }
                }
                if term.count >= 2 && completedTerm != term {
                    Section { ProgressView("Searching investments…") }
                } else if error && completedTerm == term {
                    Section {
                        Text("Market search is unavailable. You can keep a manual name in the plan.")
                        Button("Try again") { Task { await lookup(term) } }
                    }
                } else if !market.isEmpty {
                    Section("Market search") { ForEach(market) { searchRow($0) } }
                } else if term.count >= 2 && owned.isEmpty {
                    Text("No matches found. You can keep a manual name in the plan.")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TrackerStyle.background.ignoresSafeArea())
            .navigationTitle("Find investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .task(id: term) { await lookup(term) }
        }
    }

    private func searchRow(_ result: PlanSearchResult) -> some View {
        Button {
            onSelect(result)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name).foregroundStyle(.primary)
                Text([result.instrument.displayIdentifier, result.instrument.exchange, result.instrument.currency]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func lookup(_ requested: String) async {
        guard requested.count >= 2 else {
            completedTerm = requested
            results = []
            error = false
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let found = try await FinancePlanService.search(requested)
            guard !Task.isCancelled, requested == term else { return }
            results = found
            completedTerm = requested
            error = false
        } catch {
            guard !Task.isCancelled, requested == term else { return }
            results = []
            completedTerm = requested
            self.error = true
        }
    }
}
