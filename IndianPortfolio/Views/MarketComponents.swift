import SwiftUI
import Charts

// MARK: - Layout helpers

/// Width breakpoints used across the app. Layout is driven by the *actual*
/// width a view gets, not the device model, so it adapts correctly to the
/// folded (cover) screen, the unfolded inner screen in either orientation,
/// iPhone landscape, iPad multitasking and Mac.
enum LayoutMetrics {
    /// Detail screens switch to two columns above this width.
    static let twoColumnDetailWidth: CGFloat = 700
    /// Max readable content width on very wide screens.
    static let maxContentWidth: CGFloat = 1100
    /// Width of the summary side panel in wide list layouts.
    static let sidePanelWidth: CGFloat = 320
}

/// A scroll view that tells its content whether it has room for two columns.
struct AdaptiveScrollView<Content: View>: View {
    @ViewBuilder let content: (_ isWide: Bool) -> Content

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= LayoutMetrics.twoColumnDetailWidth
            ScrollView {
                content(isWide)
                    .padding()
                    .frame(maxWidth: LayoutMetrics.maxContentWidth)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Lays out `primary` and `secondary` side by side when wide, stacked otherwise.
struct AdaptiveColumns<Primary: View, Secondary: View>: View {
    let isWide: Bool
    @ViewBuilder let primary: () -> Primary
    @ViewBuilder let secondary: () -> Secondary

    var body: some View {
        if isWide {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 20) { primary() }
                    .frame(maxWidth: .infinity)
                VStack(spacing: 20) { secondary() }
                    .frame(width: 340)
            }
        } else {
            VStack(spacing: 20) {
                primary()
                secondary()
            }
        }
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat = 16) -> some View {
        padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
    }
}

// MARK: - Formatting

enum VolumeFormatter {
    static func format(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "%.1fCr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "%.1fL", value / 100_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Change label

struct ChangeLabel: View {
    let change: Double
    let percent: Double
    var font: Font = .subheadline

    private var isPositive: Bool { change >= 0 }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(CurrencyFormatter.formatChange(change))
            Text("(\(CurrencyFormatter.formatPercent(percent)))")
        }
        .font(font)
        .fontWeight(.semibold)
        .foregroundStyle(isPositive ? .green : .red)
        .monospacedDigit()
    }
}

// MARK: - Market status bar

struct MarketStatusBar: View {
    let isMarketOpen: Bool
    let exchangeRate: Double
    let lastUpdated: Date?
    var isSyncing: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if isSyncing {
                ProgressView().controlSize(.mini)
                Text("Syncing from iCloud…")
            } else {
                Circle()
                    .fill(isMarketOpen ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(MarketStatusService.statusText(isOpen: isMarketOpen))
                if let asOf = MarketStatusService.asOfText(lastUpdated) {
                    Text("· \(asOf)")
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if exchangeRate > 0 {
                Text("$1 = ₹\(String(format: "%.2f", 1.0 / exchangeRate))")
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }
}

// MARK: - Index tile

struct IndexTile: View {
    let index: MarketIndex
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 6 : 4) {
            HStack {
                Text(index.name)
                    .font(large ? .subheadline : .caption)
                    .fontWeight(.semibold)
                Spacer(minLength: 4)
                Text(index.shortName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if index.value > 0 {
                Text(CurrencyFormatter.formatIndex(index.value))
                    .font(large ? .title2 : .subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                ChangeLabel(
                    change: index.change,
                    percent: index.changePercent,
                    font: large ? .subheadline : .caption
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(large ? 14 : 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Portfolio totals

struct PortfolioTotalsView: View {
    let totalINR: Double
    let totalUSD: Double
    let dayChangeINR: Double
    let dayChangePercent: Double
    let exchangeRate: Double
    var large: Bool = false

    private var dayChangeUSD: Double { dayChangeINR * exchangeRate }

    var body: some View {
        if large {
            VStack(alignment: .leading, spacing: 10) {
                Text("Portfolio Value")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.formatUSDMillion(totalUSD))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                Text(CurrencyFormatter.formatINRCrore(totalINR))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                dayChangeRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Portfolio Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINRCrore(totalINR))
                        .font(.headline)
                        .monospacedDigit()
                    dayChangeRow
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("USD Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatUSDMillion(totalUSD))
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .monospacedDigit()
                }
            }
        }
    }

    private var dayChangeRow: some View {
        let positive = dayChangeINR >= 0
        return HStack(spacing: 4) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
            Text("Today \(positive ? "+" : "-")\(CurrencyFormatter.formatUSDMillion(abs(dayChangeUSD)))")
            Text("(\(CurrencyFormatter.formatPercent(dayChangePercent)))")
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(positive ? .green : .red)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

// MARK: - Range picker

struct RangePicker: View {
    let selected: ChartTimeRange
    let onSelect: (ChartTimeRange) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartTimeRange.allCases) { range in
                Button {
                    onSelect(range)
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(selected == range ? .bold : .regular)
                        .foregroundStyle(selected == range ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected == range ? Color.blue : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == range ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Price chart

struct PriceChartCard: View {
    let viewModel: StockDetailViewModel
    var height: CGFloat = 220
    /// Index values are shown without a currency symbol.
    var isIndex: Bool = false

    private var color: Color { viewModel.isPositive ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Price")
                    .font(.headline)
                Spacer()
                if !viewModel.priceData.isEmpty {
                    ChangeLabel(
                        change: viewModel.priceChange,
                        percent: viewModel.priceChangePercent
                    )
                }
            }

            if viewModel.isLoading && viewModel.priceData.isEmpty {
                ProgressView()
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
            } else if viewModel.priceData.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text(viewModel.errorMessage ?? "Unable to load chart data")
                )
                .frame(height: height)
            } else {
                chart
                    .frame(height: height)
                    .opacity(viewModel.isLoading ? 0.5 : 1)
            }
        }
        .cardBackground()
    }

    private var chart: some View {
        Chart {
            ForEach(viewModel.priceData) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(color)
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Time", point.timestamp),
                    yStart: .value("Base", yDomain.lowerBound),
                    yEnd: .value("Price", point.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            if viewModel.selectedRange == .oneDay, let base = previousClose {
                RuleMark(y: .value("Prev Close", base))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: viewModel.selectedRange.xAxisFormat)
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var previousClose: Double? {
        guard let pc = viewModel.liveQuote?.previousClose, pc > 0 else { return nil }
        return pc
    }

    private var yDomain: ClosedRange<Double> {
        var prices = viewModel.priceData.map(\.price)
        if viewModel.selectedRange == .oneDay, let pc = previousClose { prices.append(pc) }
        let lo = prices.min() ?? 0
        let hi = prices.max() ?? 1
        let pad = max((hi - lo) * 0.08, hi * 0.001)
        return (lo - pad)...(hi + pad)
    }
}

// MARK: - Volume chart

struct VolumeChartCard: View {
    let viewModel: StockDetailViewModel
    var height: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Volume")
                    .font(.headline)
                Spacer()
                Text(VolumeFormatter.format(viewModel.totalVolume))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Chart(viewModel.volumeData) { point in
                BarMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(Color.blue.opacity(0.6))
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: viewModel.selectedRange.xAxisFormat)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(VolumeFormatter.format(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: height)
        }
        .cardBackground()
    }
}

// MARK: - Stats

struct StatItem: Identifiable {
    let title: String
    let value: String
    var id: String { title }
}

struct StatsCard: View {
    var title: String = "Statistics"
    let items: [StatItem]
    var columns: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: max(columns, 1)),
                spacing: 12
            ) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardBackground()
    }
}
