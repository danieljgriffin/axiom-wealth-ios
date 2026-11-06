import SwiftUI

struct PlannedPurchasePicker: View {
    let onRecorded: () -> Void
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    @State private var choices: [PlannedPurchaseChoice]?
    @State private var loadFailed = false

    var body: some View {
        List {
            if let choices, !choices.isEmpty {
                Section {
                    ForEach(choices) { choice in
                        NavigationLink {
                            RecordPlannedPurchaseView(choice: choice, onRecorded: onRecorded)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(choice.name).font(.headline)
                                Text("\(choice.platform) · \(choice.instrument.displayIdentifier)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                if !isPrivateMode {
                                    Text("\(financePlanMoney(Double(choice.monthlyPence)))/month planned")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Choose an investment you’ve already bought")
                }
            } else if loadFailed {
                Section {
                    Text("Couldn’t load your linked investments.").foregroundStyle(.secondary)
                    Button("Try again") { Task { await load() } }
                }
            } else if choices != nil {
                Text("Use Find investment in the Finance plan to link a fund on a Portfolio account.")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("Loading Finance plan…")
            }
        }
        .scrollContentBackground(.hidden)
        .background(TrackerStyle.background.ignoresSafeArea())
        .navigationTitle("From your plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            choices = try await FinancePlanService.choices()
            loadFailed = false
        } catch {
            if !Task.isCancelled { loadFailed = true }
        }
    }
}

private struct RecordPlannedPurchaseView: View {
    let choice: PlannedPurchaseChoice
    let onRecorded: () -> Void
    @State private var units = ""
    @State private var cost = ""
    @State private var saving = false
    @State private var error: String?

    private var quantity: Double? { positiveValue(units) }
    private var amountSpent: Double? { positiveValue(cost) }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text(choice.name).font(.headline)
                    Text(choice.platform).font(.subheadline).foregroundStyle(.secondary)
                    Text(choice.instrument.displayIdentifier).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Enter the units and cost from your purchase confirmation. Your monthly plan stays in place.")
            }

            Section("Purchase details") {
                FinancePlanEntryField(label: "Units received", placeholder: "0", text: $units)
                FinancePlanEntryField(label: "Total amount paid (£)", text: $cost)
            }
            .disabled(saving)

            Section {
                Button(saving ? "Recording…" : "Record purchase", action: record)
                    .fontWeight(.semibold)
                    .disabled(saving || quantity == nil || amountSpent == nil)
                if let error { Text(error).font(.footnote).foregroundStyle(.orange) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(TrackerStyle.background.ignoresSafeArea())
        .navigationTitle("Record purchase")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(saving)
        .interactiveDismissDisabled(saving)
    }

    private func positiveValue(_ input: String) -> Double? {
        guard let value = Double(financePlanDecimalText(input)), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func record() {
        guard !saving, let quantity, let amountSpent else { return }
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await FinancePlanService.record(choice, units: quantity, amountSpent: amountSpent)
                onRecorded()
            } catch APIError.serverError(let status, _) where status == 404 {
                error = "This investment or account is no longer linked. Open Finance plan to review it."
            } catch {
                self.error = "Couldn’t record the purchase. Your entries are still here."
            }
        }
    }
}
