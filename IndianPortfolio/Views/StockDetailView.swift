import SwiftUI
import SwiftData
import Charts

struct StockDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let holding: StockHolding
    let quote: StockQuote?
    let exchangeRate: Double
    var onDelete: (() -> Void)? = nil

    @State private var viewModel = StockDetailViewModel()
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    /// Prefer the quote fetched by this screen; fall back to the list's quote.
    private var currentQuote: StockQuote? { viewModel.liveQuote ?? quote }

    private var holdingValueINR: Double {
        (currentQuote?.currentPrice ?? 0) * Double(holding.quantity)
    }

    private var holdingValueUSD: Double {
        guard exchangeRate > 0 else { return 0 }
        return holdingValueINR * exchangeRate
    }

    var body: some View {
        AdaptiveScrollView { isWide in
            VStack(spacing: 20) {
                headerSection(isWide: isWide)

                AdaptiveColumns(isWide: isWide) {
                    RangePicker(selected: viewModel.selectedRange) { range in
                        viewModel.changeRange(to: range, ticker: holding.ticker)
                    }
                    PriceChartCard(viewModel: viewModel, height: isWide ? 320 : 220)
                    if viewModel.hasVolume {
                        VolumeChartCard(viewModel: viewModel, height: isWide ? 140 : 120)
                    }
                } secondary: {
                    StatsCard(items: stats)
                    deleteButton
                }
            }
        }
        .navigationTitle(DisplayText.company(holding.companyName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditSheet = true }
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
                if let onDelete {
                    onDelete()
                } else {
                    modelContext.delete(holding)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \(holding.companyName) from your portfolio.")
        }
        .task(id: holding.ticker) {
            await viewModel.fetchData(for: holding.ticker)
        }
    }

    // MARK: - Header

    private func headerSection(isWide: Bool) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(holding.ticker)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ExchangeBadge(exchange: holding.exchange)

                Spacer()

                Text("\(CurrencyFormatter.formatSharesMillions(holding.quantity)) shares")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Holding Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINRCrore(holdingValueINR))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
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
                        .monospacedDigit()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
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

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Remove from Portfolio", systemImage: "trash")
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

struct ExchangeBadge: View {
    let exchange: String

    var body: some View {
        Text(exchange)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())
    }
}
