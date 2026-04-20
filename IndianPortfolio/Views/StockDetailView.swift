import SwiftUI
import SwiftData
import Charts

struct StockDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let holding: StockHolding
    let quote: StockQuote?
    let exchangeRate: Double

    @State private var viewModel = StockDetailViewModel()
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    private var holdingValueINR: Double {
        (quote?.currentPrice ?? 0) * Double(holding.quantity)
    }

    private var holdingValueUSD: Double {
        guard exchangeRate > 0 else { return 0 }
        return holdingValueINR * exchangeRate
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header: Current price & holding value
                headerSection

                // Time range picker
                timeRangePicker

                // Price chart
                priceChartSection

                // Volume chart
                volumeChartSection

                // Stats grid
                statsSection

                // Delete button
                deleteButton
            }
            .padding()
        }
        .navigationTitle(holding.companyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditStockView(holding: holding)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Delete \(holding.companyName)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(holding)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \(holding.companyName) from your portfolio.")
        }
        .task {
            await viewModel.fetchData(for: holding.ticker)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Ticker + Exchange badge
            HStack {
                Text(holding.ticker)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(holding.exchange)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Text("\(CurrencyFormatter.formatSharesMillions(holding.quantity)) shares")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Current price
            if let quote {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(CurrencyFormatter.formatINR(quote.currentPrice))
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(CurrencyFormatter.formatChange(quote.change))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(quote.isPositive ? .green : .red)

                        Text(CurrencyFormatter.formatPercent(quote.changePercent))
                            .font(.caption)
                            .foregroundStyle(quote.isPositive ? .green : .red)
                    }

                    Spacer()
                }
            }

            // Holding value
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Holding Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINRCrore(holdingValueINR))
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("USD Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatUSDMillion(holdingValueUSD))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(ChartTimeRange.allCases) { range in
                Button {
                    viewModel.changeRange(to: range, ticker: holding.ticker)
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedRange == range ? .bold : .regular)
                        .foregroundStyle(viewModel.selectedRange == range ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.selectedRange == range ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Price Chart

    private var priceChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Price")
                    .font(.headline)

                Spacer()

                if !viewModel.priceData.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isPositive ? "arrow.up.right" : "arrow.down.right")
                        Text(CurrencyFormatter.formatPercent(viewModel.priceChangePercent))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(viewModel.isPositive ? .green : .red)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
            } else if viewModel.priceData.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text(viewModel.errorMessage ?? "Unable to load chart data")
                )
                .frame(height: 220)
            } else {
                Chart(viewModel.priceData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", point.price)
                    )
                    .foregroundStyle(viewModel.isPositive ? Color.green : Color.red)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Price", point.price)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (viewModel.isPositive ? Color.green : Color.red).opacity(0.3),
                                (viewModel.isPositive ? Color.green : Color.red).opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: chartYDomain)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: viewModel.selectedRange.xAxisFormat)
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(CurrencyFormatter.formatINR(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var chartYDomain: ClosedRange<Double> {
        let prices = viewModel.priceData.map(\.price)
        let min = (prices.min() ?? 0) * 0.998
        let max = (prices.max() ?? 0) * 1.002
        return min...max
    }

    // MARK: - Volume Chart

    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Volume")
                    .font(.headline)

                Spacer()

                if viewModel.totalVolume > 0 {
                    Text(formatVolume(viewModel.totalVolume))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.volumeData.isEmpty {
                Chart(viewModel.volumeData) { point in
                    BarMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Color.blue.opacity(0.6))
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: viewModel.selectedRange.xAxisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatVolume(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 120)
            } else if !viewModel.isLoading {
                Text("No volume data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(title: "High", value: CurrencyFormatter.formatINR(viewModel.highPrice))
                statCard(title: "Low", value: CurrencyFormatter.formatINR(viewModel.lowPrice))
                statCard(title: "Prev Close", value: CurrencyFormatter.formatINR(quote?.previousClose ?? 0))
                statCard(title: "Total Volume", value: formatVolume(viewModel.totalVolume))
                if let marketCap = viewModel.marketCap ?? quote?.marketCap, marketCap > 0 {
                    statCard(title: "Mkt Cap (INR)", value: CurrencyFormatter.formatMarketCapINR(marketCap))
                    statCard(title: "Mkt Cap (USD)", value: CurrencyFormatter.formatMarketCapUSD(marketCap * exchangeRate))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Remove from Portfolio")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            )
        }
        .foregroundStyle(.red)
    }

    // MARK: - Helpers

    private func formatVolume(_ value: Double) -> String {
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
