import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var goalsViewModel = GoalsViewModel()
    @EnvironmentObject var investmentsViewModel: InvestmentsViewModel
    
    @AppStorage("isPrivateMode") private var isPrivateMode = false
    
    @State private var showingGoals = false
    
    // Colors
    private let bgDark = Color(hex: "#050816")
    private let cardBg = Color(hex: "#0B1220")
    private let positiveGreen = Color(hex: "#22C55E")
    private let negativeRed = Color(hex: "#EF4444")
    private let textSecondary = Color(hex: "#9CA3AF")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section (Not in a card)
                VStack(spacing: 16) {
                    NetWorthHeader(viewModel: viewModel, isPrivateMode: $isPrivateMode, textSecondary: textSecondary)
                    
                    // Mini Cards Row
                    HStack(spacing: 12) {
                        StatBox(
                            title: "THIS MONTH",
                            value: viewModel.summary.monthChange,
                            percent: viewModel.summary.monthChangePercent,
                            cardBg: cardBg,
                            positiveGreen: positiveGreen,
                            negativeRed: negativeRed,
                            isPrivate: false // Change is always visible
                        )
                        
                        StatBox(
                            title: "THIS YEAR",
                            value: viewModel.summary.yearChange,
                            percent: viewModel.summary.yearChangePercent,
                            cardBg: cardBg,
                            positiveGreen: positiveGreen,
                            negativeRed: negativeRed,
                            isPrivate: false // Change is always visible
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                PerformanceChartCard(viewModel: viewModel, isPrivateMode: isPrivateMode, cardBg: cardBg, textSecondary: textSecondary)
                
                GoalCard(
                    goalsViewModel: goalsViewModel,
                    dashboardViewModel: viewModel,
                    isPrivateMode: isPrivateMode,
                    cardBg: cardBg,
                    textSecondary: textSecondary
                )
                .onTapGesture {
                    showingGoals = true
                }
                
                BreakdownCard(viewModel: viewModel, isPrivateMode: isPrivateMode, cardBg: cardBg, textSecondary: textSecondary, positiveGreen: positiveGreen, negativeRed: negativeRed)
            }
            .padding(.bottom, 20)
        }
        .background(bgDark.ignoresSafeArea())
        .onAppear {
            viewModel.update(with: investmentsViewModel.platforms)
        }
        .onChange(of: investmentsViewModel.platforms) { _, newPlatforms in
            viewModel.update(with: newPlatforms)
        }
        .sheet(isPresented: $showingGoals) {
            GoalsView(viewModel: goalsViewModel, currentNetWorth: viewModel.summary.currentNetWorth)
        }
    }
}

// MARK: - Subviews

struct NetWorthHeader: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var isPrivateMode: Bool
    let textSecondary: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        Text("Portfolio")
                    }
                    .font(Font.system(.subheadline, design: .rounded))
                    .foregroundColor(textSecondary)
                    
                    Group {
                        Text(viewModel.summary.currentNetWorth, format: .currency(code: "GBP").precision(.fractionLength(0)))
                    }
                    .font(Font.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(0.1), radius: 10, x: 0, y: 0)
                    .applyPrivacyBlur(isPrivateMode)
                    
                    Group {
                        Text("Last updated: \(viewModel.summary.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    }
                    .font(Font.system(.caption, design: .rounded))
                    .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isPrivateMode.toggle()
                    }
                }) {
                    Image(systemName: isPrivateMode ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(textSecondary)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: Double
    let percent: Double
    let cardBg: Color
    let positiveGreen: Color
    let negativeRed: Color
    let isPrivate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                Text(title)
            }
            .font(Font.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.gray)
            .tracking(1)
            
            Group {
                Text(value, format: .currency(code: "GBP").precision(.fractionLength(0)).sign(strategy: .always()))
            }
            .font(Font.system(.callout, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(value >= 0 ? positiveGreen : negativeRed)
            .applyPrivacyBlur(isPrivate)
            
            Group {
                Text("(\(percent > 0 ? "+" : "")\(percent.formatted(.number.precision(.fractionLength(1))))%)")
            }
            .font(Font.system(.caption2, design: .rounded))
            .foregroundColor(value >= 0 ? positiveGreen : negativeRed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBg)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PerformanceChartCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    var isPrivateMode: Bool
    let cardBg: Color
    let textSecondary: Color
    
    @State private var selectedPoint: NetWorthPoint?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Group {
                    Text("Portfolio")
                }
                .font(Font.system(.headline, design: .rounded))
                .foregroundColor(.white)
                Spacer()
                if let selected = selectedPoint {
                    VStack(alignment: .trailing) {
                        Group {
                            Text(selected.value, format: .currency(code: "GBP").precision(.fractionLength(0)))
                        }
                        .font(Font.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .applyPrivacyBlur(isPrivateMode)
                            
                        Group {
                            Text(selected.timestamp, format: .dateTime.day().month().hour().minute())
                        }
                        .font(Font.system(.caption2, design: .rounded))
                        .foregroundColor(textSecondary)
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                }
            }
            
            Chart {
                ForEach(viewModel.currentSeries) { point in
                    LineMark(
                        x: .value("Date", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#22D3EE"), Color(hex: "#3B82F6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                if let selected = selectedPoint {
                    RuleMark(x: .value("Date", selected.timestamp))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    
                    PointMark(
                        x: .value("Date", selected.timestamp),
                        y: .value("Value", selected.value)
                    )
                    .foregroundStyle(Color.white)
                    .symbolSize(50)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: viewModel.yAxisTicks) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Group {
                                Text(doubleValue, format: .currency(code: "GBP").precision(.fractionLength(0)))
                            }
                            .foregroundStyle(textSecondary)
                            .font(.caption2)
                            .applyPrivacyBlur(isPrivateMode)
                        }
                    }
                }
            }
            .chartYScale(domain: viewModel.yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel(format: xAxisFormat(for: viewModel.selectedRange), anchor: .center)
                        .foregroundStyle(textSecondary)
                        .font(.caption2)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        // Find nearest point
                                        if let nearest = viewModel.currentSeries.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }) {
                                            selectedPoint = nearest
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    selectedPoint = nil
                                }
                        )
                }
            }
            .frame(height: 220)
            
            // Time Range Selector
            HStack(spacing: 0) {
                ForEach(TimeRange.allCases) { range in
                    Button(action: { viewModel.updateRange(range) }) {
                        Group {
                            Text(range.rawValue)
                        }
                        .font(Font.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(viewModel.selectedRange == range ? .white : textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedRange == range ?
                            LinearGradient(colors: [Color(hex: "#22D3EE"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
        }
        .padding(20)
        .background(cardBg)
        .cornerRadius(20)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(.horizontal)
        )
    }
    
    private func xAxisFormat(for range: TimeRange) -> Date.FormatStyle {
        switch range {
        case .h24:
            return .dateTime.hour().minute()
        case .w1:
            return .dateTime.weekday()
        case .m1, .m3:
            return .dateTime.day().month()
        case .m6, .y1, .max:
            return .dateTime.month().year()
        }
    }
}



struct GoalCard: View {
    @ObservedObject var goalsViewModel: GoalsViewModel
    @ObservedObject var dashboardViewModel: DashboardViewModel
    var isPrivateMode: Bool
    let cardBg: Color
    let textSecondary: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let goal = goalsViewModel.activeGoal {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 8) {
                            Group {
                                Text("Current Goal")
                            }
                            .font(Font.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                            
                            HStack(spacing: 2) {
                                Text("Manage")
                                Image(systemName: "chevron.right")
                                    .font(Font.system(size: 8, weight: .bold))
                            }
                            .font(Font.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        Group {
                            Text("\(goal.targetAmount.formatted(.currency(code: "GBP").precision(.fractionLength(0)))) by \(goal.targetDate.formatted(.dateTime.month().year()))")
                        }
                        .font(Font.system(.subheadline, design: .rounded))
                        .foregroundColor(textSecondary)
                        .applyPrivacyBlur(isPrivateMode)
                    }
                    Spacer()
                    
                    let progress = goal.progress(currentAmount: dashboardViewModel.summary.currentNetWorth)
                    Group {
                        Text(progress, format: .percent.precision(.fractionLength(1)))
                    }
                    .font(Font.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#22D3EE"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing)
                    )
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 12)
                        
                        let progress = goal.progress(currentAmount: dashboardViewModel.summary.currentNetWorth)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(colors: [Color(hex: "#22D3EE"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geometry.size.width * progress, height: 12)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text(dashboardViewModel.summary.currentNetWorth, format: .currency(code: "GBP").precision(.fractionLength(0)))
                        .applyPrivacyBlur(isPrivateMode)
                    Spacer()
                    Text(goal.targetAmount, format: .currency(code: "GBP").precision(.fractionLength(0)))
                        .applyPrivacyBlur(isPrivateMode)
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(textSecondary)
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading) {
                        Group {
                            Text("DAYS REMAINING")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(textSecondary)
                        
                        Group {
                            Text("\(goal.daysRemaining())")
                        }
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Group {
                            Text("REMAINING")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(textSecondary)
                        
                        let remaining = max(goal.targetAmount - dashboardViewModel.summary.currentNetWorth, 0)
                        Group {
                            Text(remaining, format: .currency(code: "GBP").precision(.fractionLength(0)))
                        }
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .applyPrivacyBlur(isPrivateMode)
                    }
                }
            } else {
                // Empty State
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Group {
                            Text("No Active Goal")
                        }
                        .font(Font.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                        Group {
                            Text("Tap to set a financial goal")
                        }
                        .font(Font.system(.subheadline, design: .rounded))
                        .foregroundColor(textSecondary)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(20)
        .background(cardBg)
        .cornerRadius(20)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(.horizontal)
        )
    }
}

struct BreakdownCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    var isPrivateMode: Bool
    let cardBg: Color
    let textSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    Text("Portfolio Breakdown")
                }
                .font(Font.system(.headline, design: .rounded))
                .foregroundColor(.white)
                Group {
                    Text("% of portfolio")
                }
                .font(Font.system(.subheadline, design: .rounded))
                .foregroundColor(textSecondary)
            }
            
            VStack(spacing: 0) {
                ForEach(viewModel.platforms) { item in
                    BreakdownRow(item: item, textSecondary: textSecondary, positiveGreen: positiveGreen, negativeRed: negativeRed, isPrivate: isPrivateMode, isLast: item.id == viewModel.platforms.last?.id)
                }
            }
        }
        .padding(20)
        .background(cardBg)
        .cornerRadius(20)
        .padding(.horizontal)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(.horizontal)
        )
    }
}

struct BreakdownRow: View {
    let item: DashboardPlatformItem
    let textSecondary: Color
    let positiveGreen: Color
    let negativeRed: Color
    let isPrivate: Bool
    let isLast: Bool
    
    var body: some View {
        HStack {
            // Left
            HStack(spacing: 12) {
                Circle()
                    .fill(item.color)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        Text(item.name)
                    }
                    .font(Font.system(.body, design: .rounded))
                    .foregroundColor(.white)
                    Group {
                        Text("\(item.percentage.formatted(.number.precision(.fractionLength(1))))% of portfolio")
                    }
                    .font(Font.system(.caption, design: .rounded))
                    .foregroundColor(textSecondary)
                }
            }
            
            Spacer()
            
            // Right
            VStack(alignment: .trailing, spacing: 2) {
                Group {
                    Text(item.value, format: .currency(code: "GBP").precision(.fractionLength(0)))
                }
                .font(Font.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .applyPrivacyBlur(isPrivate)
                
                Group {
                    Text("\(item.monthChange > 0 ? "+" : "")\(item.monthChange.formatted(.currency(code: "GBP").precision(.fractionLength(0)))) (\(item.monthChange > 0 ? "+" : "")\(item.monthChangePercent.formatted(.number.precision(.fractionLength(1))))%)")
                }
                .font(Font.system(.caption, design: .monospaced))
                .foregroundColor(item.monthChange >= 0 ? positiveGreen : negativeRed)
            }
        }
        .padding(.vertical, 12)
        
        if !isLast {
            Divider().background(Color.white.opacity(0.1))
        }
    }
}

#Preview {
    DashboardView()
}
