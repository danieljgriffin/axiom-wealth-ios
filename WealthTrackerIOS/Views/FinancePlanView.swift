import SwiftUI

struct FinancePlanView: View {
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    @State private var plan: FinancePlan?
    @State private var loaded = false
    @State private var error = false
    @State private var editing: FinancePlanSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finance plan").font(.title.bold()).accessibilityAddTraits(.isHeader)
                    Text("Your ongoing plan for take-home pay, bills and investments.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                if error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn’t load the Finance plan.").foregroundStyle(.secondary)
                        Button("Try again") { Task { await load() } }
                    }
                    .financePlanCard()
                }

                if loaded {
                    overview
                    bills
                    investments
                } else if !error {
                    ProgressView("Loading Finance plan…").frame(maxWidth: .infinity, minHeight: 150)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(TrackerStyle.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { section in
            FinancePlanEditor(section: section, initial: plan ?? FinancePlan()) { saved in
                plan = saved
                error = false
            }
        }
    }

    private var overview: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Free to spend").font(.headline).accessibilityAddTraits(.isHeader)
                FinancePeriodAmounts(annualPence: plan.map { Double($0.annualFree) },
                                     color: isPrivateMode ? .primary : (plan?.annualFree ?? 0) < 0 ? .red : .green,
                                     prominent: true)
            }
            .financePlanCard()

            VStack(alignment: .leading, spacing: 8) {
                cardHeader("Take-home pay", section: .pay)
                FinancePeriodAmounts(annualPence: plan.map { Double($0.annualPay) }, prominent: true)
            }
            .financePlanCard()
        }
    }

    private var bills: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Bills and commitments", section: .bills)
            if let plan, !plan.bills.isEmpty {
                DisclosureGroup {
                    ForEach(plan.bills.indices, id: \.self) { index in
                        let bill = plan.bills[index]
                        Divider().padding(.vertical, 5)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bill.name).font(.subheadline)
                            if bill.frequency == .annual {
                                Text("Yearly bill · monthly equivalent shown").font(.caption).foregroundStyle(.secondary)
                            }
                            FinancePeriodAmounts(annualPence: Double(bill.annualPence))
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    FinancePeriodAmounts(annualPence: Double(plan.annualBills))
                        .accessibilityHint("Shows the individual bills")
                }
                .tint(.secondary)
            } else {
                Text("Add your recurring bills and commitments.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .financePlanCard()
    }

    private var investments: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("Planned investments", section: .investments)
            if let plan, !plan.allocations.isEmpty {
                if !isPrivateMode && plan.take_home_monthly_pence > 0 {
                    Text("\(share(plan.monthlyInvestments, of: plan.take_home_monthly_pence)) of annual take-home pay")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                FinancePeriodAmounts(annualPence: Double(plan.monthlyInvestments) * 12, prominent: true)
                ForEach(plan.allocations.sorted { $0.displayOrder < $1.displayOrder }) { allocation in
                    Divider()
                    DisclosureGroup {
                        allocationDetails(allocation, total: plan.monthlyInvestments)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(allocation.platform).font(.subheadline.weight(.semibold))
                            FinancePeriodAmounts(annualPence: Double(allocation.amount_pence) * 12,
                                                 share: investmentShare(allocation.amount_pence, of: plan.monthlyInvestments))
                        }
                    }
                    .tint(.secondary)
                }
            } else {
                Text("Add a platform and the investments you plan to buy.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .financePlanCard()
    }

    private func cardHeader(_ title: String, section: FinancePlanSection) -> some View {
        HStack {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { editing = section } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(section.editTitle)
        }
    }

    private func allocationDetails(_ allocation: FinancePlan.Allocation, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if allocation.funds.isEmpty {
                Text("No individual investments listed.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(allocation.funds.indices, id: \.self) { index in
                let fund = allocation.funds[index]
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(fund.name).font(.subheadline)
                    if let instrument = fund.instrument {
                        Text(instrument.displayIdentifier).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    FinancePeriodAmounts(annualPence: Double(fund.amount_pence) * 12, share: investmentShare(fund.amount_pence, of: total))
                }
            }
            if !isPrivateMode, !allocation.funds.isEmpty, allocation.unallocatedPence != 0 {
                Text(allocation.unallocatedPence < 0
                     ? "Listed investments exceed the platform total by \(financePlanMoney(Double(-allocation.unallocatedPence))) per month."
                     : "\(financePlanMoney(Double(allocation.unallocatedPence))) per month unallocated to investments.")
                    .font(.footnote).foregroundStyle(allocation.unallocatedPence < 0 ? Color.orange : Color.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func share(_ amount: Int, of total: Int) -> String {
        (Double(amount) / Double(total)).formatted(.percent.precision(.fractionLength(0...1)))
    }

    private func investmentShare(_ amount: Int, of total: Int) -> String? {
        total > 0 ? share(amount, of: total) : nil
    }

    private func load() async {
        do {
            let saved = try await FinancePlanService.fetch()
            guard !Task.isCancelled else { return }
            plan = saved
            loaded = true
            error = false
        } catch {
            if !Task.isCancelled { self.error = true }
        }
    }
}

struct FinancePeriodAmounts: View {
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let annualPence: Double?
    var color: Color = .primary
    var prominent = false
    var share: String?

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            metric("Monthly", value: annualPence.map { financePlanMoney($0 / 12) })
            metric("Annual", value: annualPence.map(financePlanMoney))
            if let share { metric("Share", value: share) }
        }
    }

    private func metric(_ label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value.map { isPrivateMode ? "••••" : $0 } ?? "—")
                .font(prominent ? .title3.bold() : .subheadline.weight(.semibold))
                .foregroundStyle(value == nil || isPrivateMode ? Color.primary : color)
                .monospacedDigit()
                .accessibilityLabel(isPrivateMode && value != nil ? "Hidden value" : value ?? "No value")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

func financePlanMoney(_ pence: Double) -> String {
    (pence / 100).formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")))
}

private extension View {
    func financePlanCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(TrackerStyle.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
