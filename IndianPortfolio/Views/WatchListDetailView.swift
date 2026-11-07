import SwiftUI
import SwiftData
import Charts

struct WatchListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: WatchListItem
    let quote: StockQuote?
    let exchangeRate: Double
    var onDelete: (() -> Void)? = nil

    @State private var viewModel = StockDetailViewModel()
    @State private var showingDeleteConfirmation = false

    private var currentQuote: StockQuote? { viewModel.liveQuote ?? quote }

    var body: some View {
        AdaptiveScrollView { isWide in
            VStack(spacing: 20) {
                headerSection

                AdaptiveColumns(isWide: isWide) {
                    RangePicker(selected: viewModel.selectedRange) { range in
                        viewModel.changeRange(to: range, ticker: item.ticker)
                    }
                    PriceChartCard(viewModel: viewModel, height: isWide ? 320 : 220)
                    if viewModel.hasVolume {
                        VolumeChartCard(viewModel: viewModel, height: isWide ? 140 : 120)
                    }
                } secondary: {
                    StatsCard(items: stats)
                    removeButton
                }
            }
        }
        .navigationTitle(DisplayText.company(item.companyName))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove \(item.companyName)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let onDelete {
                    onDelete()
                } else {
                    modelContext.delete(item)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(item.companyName) from your Watch List.")
        }
        .task(id: item.ticker) {
            await viewModel.fetchData(for: item.ticker)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(item.ticker)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ExchangeBadge(exchange: item.exchange)
                Spacer()
            }

            if let q = currentQuote {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(CurrencyFormatter.formatINR(q.currentPrice))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    ChangeLabel(change: q.change, percent: q.changePercent)

                    Spacer()

                    if let asOf = MarketStatusService.asOfText(q.lastUpdated) {
                        Text(asOf)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Stats

    private var stats: [StatItem] {
        var items: [StatItem] = [
            StatItem(title: "\(viewModel.selectedRange.rawValue) High", value: CurrencyFormatter.formatINR(viewModel.highPrice)),
            StatItem(title: "\(viewModel.selectedRange.rawValue) Low", value: CurrencyFormatter.formatINR(viewModel.lowPrice)),
            StatItem(title: "Prev Close", value: CurrencyFormatter.formatINR(currentQuote?.previousClose ?? 0)),
            StatItem(title: "Volume", value: VolumeFormatter.format(viewModel.totalVolume)),
        ]
        if let cap = viewModel.marketCap ?? currentQuote?.marketCap, cap > 0 {
            items.append(StatItem(title: "Mkt Cap (INR)", value: CurrencyFormatter.formatMarketCapINR(cap)))
            if exchangeRate > 0 {
                items.append(StatItem(title: "Mkt Cap (USD)", value: CurrencyFormatter.formatMarketCapUSD(cap * exchangeRate)))
            }
        }
        return items
    }

    // MARK: - Remove Button

    private var removeButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Remove from Watch List", systemImage: "minus.circle")
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
        }
        .foregroundStyle(.red)
    }
}
