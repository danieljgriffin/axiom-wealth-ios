import SwiftUI
import Charts

struct ShareCardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRange: TimeRange = .m1
    @State private var showPoundValues: Bool = false
    @State private var shareChartData: [NetWorthPoint] = []
    @State private var isLoadingChart: Bool = false
    @State private var renderedImage: UIImage?
    @State private var showShareSheet: Bool = false
    
    // Colors
    private let bgDark = Color(hex: "#050816")
    private let cardBg = Color(hex: "#0B1220")
    private let textSecondary = Color(hex: "#9CA3AF")
    private let accentCyan = Color(hex: "#22D3EE")
    private let accentBlue = Color(hex: "#3B82F6")
    private let positiveGreen = Color(hex: "#22C55E")
    private let negativeRed = Color(hex: "#EF4444")
    
    var body: some View {
        ZStack {
            bgDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Share Your Progress")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer to balance the X button
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Card Preview
                        shareCardContent
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#0F172A"),
                                                Color(hex: "#0B1220"),
                                                Color(hex: "#0F172A")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [accentCyan.opacity(0.3), accentBlue.opacity(0.1), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: accentCyan.opacity(0.1), radius: 20, x: 0, y: 10)
                            .padding(.horizontal, 20)
                        
                        // Timeline Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TIME PERIOD")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(textSecondary)
                                .tracking(1)
                            
                            HStack(spacing: 0) {
                                ForEach(TimeRange.allCases) { range in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedRange = range
                                        }
                                        loadChartData()
                                    }) {
                                        Text(range.rawValue)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(selectedRange == range ? .white : textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedRange == range ?
                                                LinearGradient(colors: [accentCyan, accentBlue], startPoint: .leading, endPoint: .trailing) :
                                                LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)
                        
                        // Show £ Values Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show £ values")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                Text("Include exact figures on the shared card")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $showPoundValues)
                                .tint(accentCyan)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(cardBg)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
                
                // Share Button
                Button(action: {
                    renderAndShare()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Share")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [accentCyan, accentBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Initialize with current dashboard data
            selectedRange = viewModel.selectedRange
            shareChartData = viewModel.currentSeries
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheetView(image: image)
            }
        }
    }
    
    // MARK: - Share Card Content (This gets rendered to image)
    
    @ViewBuilder
    private var shareCardContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Worth")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(textSecondary)
                    
                    if showPoundValues {
                        Text(viewModel.summary.currentNetWorth, format: .currency(code: "GBP").precision(.fractionLength(0)))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text("••••••")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                
                Spacer()
                
                // App branding
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(colors: [accentCyan, accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("WealthTracker")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(textSecondary)
                        .tracking(0.5)
                }
            }
            
            // Performance Badge
            let change = changeForSelectedRange
            let isPositive = change >= 0
            
            HStack(spacing: 8) {
                // % Badge
                HStack(spacing: 5) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    
                    Text("\(isPositive ? "+" : "")\(change.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    
                    Text(selectedRange.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isPositive ? positiveGreen.opacity(0.7) : negativeRed.opacity(0.7))
                }
                .foregroundColor(isPositive ? positiveGreen : negativeRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((isPositive ? positiveGreen : negativeRed).opacity(0.12))
                .cornerRadius(8)
                
                // £ Badge (only when Show £ values is on)
                if showPoundValues {
                    HStack(spacing: 5) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        
                        Text(changeAmountForSelectedRange, format: .currency(code: "GBP").precision(.fractionLength(0)).sign(strategy: .always()))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isPositive ? positiveGreen : negativeRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isPositive ? positiveGreen : negativeRed).opacity(0.12))
                    .cornerRadius(8)
                }
            }
            
            // Chart
            if shareChartData.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .frame(height: 160)
                    .overlay(
                        ProgressView()
                            .tint(accentCyan)
                    )
            } else {
                Chart {
                    ForEach(shareChartData) { point in
                        let minValue = shareChartData.map(\.value).min() ?? 0
                        
                        AreaMark(
                            x: .value("Date", point.timestamp),
                            yStart: .value("Min", minValue),
                            yEnd: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentCyan.opacity(0.3), accentBlue.opacity(0.05), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Date", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentCyan, accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis {
                    if showPoundValues {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(doubleValue, format: .currency(code: "GBP").precision(.fractionLength(0)))
                                        .foregroundStyle(textSecondary)
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    } else {
                        AxisMarks(position: .trailing) { _ in }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel(format: xAxisFormat(for: selectedRange), anchor: .center)
                            .foregroundStyle(textSecondary)
                            .font(.system(size: 9))
                    }
                }
                .chartYScale(domain: shareChartYDomain)
                .frame(height: 160)
            }
            
            // Footer
            HStack {
                Text("Tracked across \(viewModel.platforms.count) platforms")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(textSecondary)
                
                Spacer()
                
                Text(Date(), format: .dateTime.day().month().year())
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(textSecondary.opacity(0.6))
            }
        }
        .clipped()
    }
    
    // MARK: - Helpers
    
    private var changeForSelectedRange: Double {
        // Use the dashboard's existing calculations for known ranges
        switch selectedRange {
        case .ytd, .y1, .max:
            return viewModel.summary.yearChangePercent
        case .m1:
            return viewModel.summary.monthChangePercent
        default:
            // For other ranges, calculate from chart data
            guard shareChartData.count >= 2,
                  let firstValue = shareChartData.first?.value,
                  let lastValue = shareChartData.last?.value,
                  firstValue > 0 else {
                return viewModel.summary.monthChangePercent
            }
            return ((lastValue - firstValue) / firstValue) * 100
        }
    }
    
    private var changeAmountForSelectedRange: Double {
        switch selectedRange {
        case .ytd, .y1, .max:
            return viewModel.summary.yearChange
        case .m1:
            return viewModel.summary.monthChange
        default:
            guard shareChartData.count >= 2,
                  let firstValue = shareChartData.first?.value,
                  let lastValue = shareChartData.last?.value else {
                return viewModel.summary.monthChange
            }
            return lastValue - firstValue
        }
    }
    
    private func xAxisFormat(for range: TimeRange) -> Date.FormatStyle {
        switch range {
        case .h24:
            return .dateTime.hour().minute()
        case .w1:
            return .dateTime.weekday()
        case .m1, .m3:
            return .dateTime.day().month()
        case .ytd, .m6, .y1, .max:
            return .dateTime.month().year()
        }
    }
    
    private var shareChartYDomain: ClosedRange<Double> {
        guard !shareChartData.isEmpty else { return 0...100 }
        let values = shareChartData.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        
        if minVal == maxVal {
            return (minVal * 0.9)...(minVal * 1.1)
        }
        
        let range = maxVal - minVal
        let padding = range * 0.05
        return (minVal - padding)...(maxVal + padding)
    }
    
    private func loadChartData() {
        isLoadingChart = true
        Task {
            do {
                let points = try await WealthService.shared.fetchDashboardHistory(period: selectedRange.apiPeriod)
                await MainActor.run {
                    withAnimation {
                        shareChartData = points
                        isLoadingChart = false
                    }
                }
            } catch {
                print("ShareCard: Error loading chart data: \(error)")
                await MainActor.run {
                    isLoadingChart = false
                }
            }
        }
    }
    
    private func renderAndShare() {
        // Build the card view for rendering
        let cardView = shareCardContent
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#0F172A"),
                                Color(hex: "#0B1220"),
                                Color(hex: "#0F172A")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .padding(16)
            .background(bgDark)
            .frame(width: 400)
        
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // High resolution
        
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            showShareSheet = true
        }
    }
}

// MARK: - iOS Share Sheet Wrapper

struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareCardView(viewModel: DashboardViewModel())
}
