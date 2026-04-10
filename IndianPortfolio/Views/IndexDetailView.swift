import SwiftUI
import Charts

struct IndexDetailView: View {
    let index: MarketIndex

    @State private var viewModel = StockDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Time range picker
                timeRangePicker

                // Price chart
                priceChartSection

                // Volume chart
                volumeChartSection

                // Stats grid
                statsSection
            }
            .padding()
        }
        .navigationTitle(index.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchData(for: index.id)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(index.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(format: "%.2f", index.value))
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 2) {
                    Text(CurrencyFormatter.formatChange(index.change))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(index.isPositive ? .green : .red)

                    Text(CurrencyFormatter.formatPercent(index.changePercent))
                        .font(.caption)
                        .foregroundStyle(index.isPositive ? .green : .red)
                }

                Spacer()
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(ChartTimeRange.allCases) { range in
                Button {
                    viewModel.changeRange(to: range, ticker: index.id)
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
                                Text(String(format: "%.0f", v))
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
                statCard(title: "High", value: String(format: "%.2f", viewModel.highPrice))
                statCard(title: "Low", value: String(format: "%.2f", viewModel.lowPrice))
                statCard(title: "Change", value: CurrencyFormatter.formatChange(index.change))
                statCard(title: "Total Volume", value: formatVolume(viewModel.totalVolume))
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
