import SwiftUI

struct RecordTrackerActivityView: View {
    private enum Kind: String, CaseIterable {
        case payOrDeposit = "Pay or deposit"
        case withdrawal = "Withdrawal"
        case transfer = "Transfer"
    }

    let platforms: [String]
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind = Kind.payOrDeposit
    @State private var pay = ""
    @State private var deposit = ""
    @State private var payDate = Date()
    @State private var depositDate = Date()
    @State private var depositPlatform = ""
    @State private var amount = ""
    @State private var movementDate = Date()
    @State private var source = ""
    @State private var destination = ""
    @State private var note = ""
    @State private var pendingSubmission: TrackerSubmission?
    @State private var isSaving = false
    @State private var error: String?
    @State private var confirmClose = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        Picker("Activity", selection: $kind) {
                            ForEach(Kind.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }

                    switch kind {
                    case .payOrDeposit:
                        Section {
                            amountField("Take-home pay", text: $pay)
                            DatePicker("Date received", selection: $payDate, in: ...Date(), displayedComponents: .date)
                        } header: {
                            Text("Pay")
                        } footer: {
                            Text("You can record pay, a deposit, or both.")
                        }
                        Section {
                            amountField("Deposit amount", text: $deposit)
                            DatePicker("Date deposited", selection: $depositDate, in: ...Date(), displayedComponents: .date)
                            platformPicker("Receiving platform", selection: $depositPlatform, placeholder: "Optional")
                        } header: {
                            Text("New investment deposit")
                        } footer: {
                            Text("Enter money paid into an investment account. This updates monthly contributions and the yearly Invested total.")
                        }
                    case .withdrawal, .transfer:
                        Section {
                            amountField("Amount in pounds", text: $amount)
                            DatePicker("Effective date", selection: $movementDate, in: ...Date(), displayedComponents: .date)
                            platformPicker("From", selection: $source, placeholder: "Choose a platform")
                            if kind == .transfer {
                                platformPicker("To", selection: $destination, placeholder: "Choose a platform")
                            }
                        } footer: {
                            Text(kind == .withdrawal
                                 ? "Use this when money leaves your investment accounts, including payments sent directly from a platform."
                                 : "Use this for a completed move between two investment platforms.")
                        }
                    }

                    Section("Optional note") {
                        TextField("Add a note", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                .disabled(isSaving || pendingSubmission != nil)

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
                if isSaving {
                    ProgressView("Saving activity…")
                }
            }
            .navigationTitle("Record activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if pendingSubmission == nil {
                            dismiss()
                        } else {
                            confirmClose = true
                        }
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(pendingSubmission == nil || isSaving ? "Save" : "Retry") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .confirmationDialog("Save status unknown", isPresented: $confirmClose) {
                Button("Close draft", role: .destructive) { dismiss() }
            } message: {
                Text("Check Tracker before recording this activity again.")
            }
        }
        .interactiveDismissDisabled(isSaving || pendingSubmission != nil)
    }

    private func platformPicker(_ label: String, selection: Binding<String>, placeholder: String) -> some View {
        Picker(label, selection: selection) {
            Text(placeholder).tag("")
            ForEach(platforms, id: \.self) { platform in
                Text(platform).tag(platform)
            }
        }
    }

    private func makeSubmission() throws -> TrackerSubmission {
        let key = UUID().uuidString
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanNote.count <= 500 else { throw TrackerFormError("Keep the note to 500 characters.") }

        switch kind {
        case .payOrDeposit:
            guard let payValue = TrackerMoneyInput.parse(pay, blankIsZero: true),
                  let depositValue = TrackerMoneyInput.parse(deposit, blankIsZero: true) else {
                throw TrackerFormError("Enter valid amounts in pounds with up to two decimal places.")
            }
            guard payValue > 0 || depositValue > 0 else {
                throw TrackerFormError("Enter a pay amount, a deposit amount, or both.")
            }
            return .entry(TrackerEntryRequest(
                entry_key: key,
                income_amount: payValue,
                income_date: payValue > 0 ? TrackerService.dateString(payDate) : nil,
                investment_amount: depositValue,
                investment_date: depositValue > 0 ? TrackerService.dateString(depositDate) : nil,
                destination_platform: depositValue > 0 && !depositPlatform.isEmpty ? depositPlatform : nil,
                note: cleanNote.isEmpty ? nil : cleanNote
            ))
        case .withdrawal, .transfer:
            guard let value = TrackerMoneyInput.parse(amount), value > 0 else {
                throw TrackerFormError("Enter an amount greater than £0 with up to two decimal places.")
            }
            guard platforms.contains(source) else { throw TrackerFormError("Choose the source platform.") }
            if kind == .transfer {
                guard platforms.contains(destination) else { throw TrackerFormError("Choose the receiving platform.") }
                guard source != destination else { throw TrackerFormError("Choose two different platforms.") }
            }
            return .movement(TrackerMovementRequest(
                event_key: key,
                flow_type: kind == .withdrawal ? "withdrawal" : "transfer",
                amount: value,
                effective_date: TrackerService.dateString(movementDate),
                source_platform: source,
                destination_platform: kind == .transfer ? destination : nil,
                note: cleanNote.isEmpty ? nil : cleanNote
            ))
        }
    }

    private func save() async {
        guard !isSaving else { return }
        error = nil
        isSaving = true
        defer { isSaving = false }

        do {
            let submission = try pendingSubmission ?? makeSubmission()
            pendingSubmission = submission
            try await TrackerService.save(submission)
            pendingSubmission = nil
            await onSave()
            dismiss()
        } catch let formError as TrackerFormError {
            error = formError.message
        } catch {
            if let message = TrackerFormError.rejectedRequestMessage(error) {
                pendingSubmission = nil
                self.error = message
            } else {
                self.error = "Couldn’t confirm the save. Tap Retry to check or finish the same submission."
            }
        }
    }
}

struct EditTrackerTotalsView: View {
    let year: Int
    let currentYear: Int
    let totals: APIIncomeData?
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var income: String
    @State private var invested: String
    @State private var isSaving = false
    @State private var error: String?

    init(year: Int, currentYear: Int, totals: APIIncomeData?, onSave: @escaping () async -> Void) {
        self.year = year
        self.currentYear = currentYear
        self.totals = totals
        self.onSave = onSave
        _income = State(initialValue: TrackerMoneyInput.editText(totals?.income ?? 0))
        _invested = State(initialValue: TrackerMoneyInput.editText(totals?.investment ?? 0))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    amountField("Take-home income", text: $income)
                    amountField("Invested", text: $invested)
                } header: {
                    Text("\(String(year)) annual totals")
                } footer: {
                    Text("Enter the full-year totals. Use Record activity for individual pay and deposits.")
                }
                .disabled(isSaving)

                if year == currentYear, let investment = editedValue(invested, original: totals?.investment) {
                    let difference = investment - (totals?.investment ?? 0)
                    if difference > 0 {
                        Section("Effect on Return") {
                            Text("Saving adds \(difference.formatted(TrackerStyle.money)) to this month’s contributions and updates the year-to-date invested total.")
                        }
                    } else if difference < 0 {
                        Section("Effect on Return") {
                            Text("Saving lowers the year-to-date invested total. Previously recorded contributions still count in the months they were recorded.")
                        }
                    }
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
                if isSaving { ProgressView("Saving totals…") }
            }
            .navigationTitle("Edit totals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func editedValue(_ text: String, original: Double?) -> Double? {
        if let original, text == TrackerMoneyInput.editText(original) { return original }
        return TrackerMoneyInput.parse(text)
    }

    private func save() async {
        guard !isSaving else { return }
        guard let incomeValue = editedValue(income, original: totals?.income),
              let investment = editedValue(invested, original: totals?.investment) else {
            error = "Enter both totals in pounds with up to two decimal places."
            return
        }
        if incomeValue == totals?.income && investment == totals?.investment {
            dismiss()
            return
        }

        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await TrackerService.updateTotals(year: year, income: incomeValue, investment: investment)
            await onSave()
            dismiss()
        } catch {
            self.error = TrackerFormError.rejectedRequestMessage(error) ?? "Couldn’t confirm the totals were saved. Please try again."
        }
    }
}

private func amountField(_ label: String, text: Binding<String>) -> some View {
    LabeledContent(label) {
        TextField(label, text: text, prompt: Text("£0.00"))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
    }
}

private struct TrackerFormError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    static func rejectedRequestMessage(_ error: Error) -> String? {
        guard case APIError.serverError(let status, let body) = error,
              (400..<500).contains(status), status != 408 else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
           let detail = json["detail"] as? String {
            return detail
        }
        return "The app couldn’t save these details. Check your entries and try again."
    }
}

private enum TrackerMoneyInput {
    static func editText(_ amount: Double) -> String {
        amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    static func parse(_ text: String, blankIsZero: Bool = false) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return blankIsZero ? 0 : nil }
        let normalized = trimmed.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^(?:[0-9]+(?:\.[0-9]{0,2})?|\.[0-9]{1,2})$"#, options: .regularExpression) != nil,
              let amount = Double(normalized), amount.isFinite else { return nil }
        return amount
    }
}
