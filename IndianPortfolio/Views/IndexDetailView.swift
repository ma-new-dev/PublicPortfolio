import SwiftUI
import Charts

struct IndexDetailView: View {
    let index: MarketIndex

    @State private var viewModel = StockDetailViewModel()

    /// Live value fetched by this screen; falls back to the snapshot passed in.
    private var value: Double { viewModel.liveQuote?.currentPrice ?? index.value }
    private var change: Double { viewModel.liveQuote?.change ?? index.change }
    private var changePercent: Double { viewModel.liveQuote?.changePercent ?? index.changePercent }
    private var previousClose: Double { viewModel.liveQuote?.previousClose ?? index.previousClose }
    private var lastUpdated: Date? { viewModel.liveQuote?.lastUpdated ?? index.lastUpdated }

    var body: some View {
        AdaptiveScrollView { isWide in
            VStack(spacing: 20) {
                headerSection

                AdaptiveColumns(isWide: isWide) {
                    RangePicker(selected: viewModel.selectedRange) { range in
                        viewModel.changeRange(to: range, ticker: index.id, includeMarketCap: false)
                    }
                    PriceChartCard(viewModel: viewModel, height: isWide ? 340 : 240, isIndex: true)
                    // Yahoo reports no volume for NSE/BSE indices; only show it if present.
                    if viewModel.hasVolume {
                        VolumeChartCard(viewModel: viewModel, height: isWide ? 140 : 120)
                    }
                } secondary: {
                    StatsCard(items: stats, columns: 2)
                }
            }
        }
        .navigationTitle(index.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: index.id) {
            await viewModel.fetchData(for: index.id, includeMarketCap: false)
        }
        .refreshable {
            await viewModel.fetchData(for: index.id, includeMarketCap: false)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                ExchangeBadge(exchange: index.shortName)
                Spacer()
                if let asOf = MarketStatusService.asOfText(lastUpdated) {
                    Text(asOf)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(CurrencyFormatter.formatIndex(value))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                ChangeLabel(change: change, percent: changePercent)

                Spacer()
            }
        }
    }

    // MARK: - Stats

    private var stats: [StatItem] {
        let range = viewModel.selectedRange.rawValue
        return [
            StatItem(title: "Prev Close", value: CurrencyFormatter.formatIndex(previousClose)),
            StatItem(title: "Day Change", value: CurrencyFormatter.formatChange(change)),
            StatItem(title: "\(range) High", value: CurrencyFormatter.formatIndex(viewModel.highPrice)),
            StatItem(title: "\(range) Low", value: CurrencyFormatter.formatIndex(viewModel.lowPrice)),
            StatItem(title: "\(range) Change", value: CurrencyFormatter.formatPercent(viewModel.priceChangePercent)),
        ]
    }
}
