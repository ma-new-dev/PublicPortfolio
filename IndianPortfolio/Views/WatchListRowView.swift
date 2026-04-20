import SwiftUI

struct WatchListRowView: View {
    let item: WatchListItem
    let quote: StockQuote?

    var body: some View {
        HStack(spacing: 12) {
            // Left: Company info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.companyName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.ticker)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(item.exchange)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Right: Price + day change
            if let quote {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(CurrencyFormatter.formatINR(quote.currentPrice))
                        .font(.headline)

                    HStack(spacing: 4) {
                        Text(CurrencyFormatter.formatChange(quote.change))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(quote.isPositive ? .green : .red)

                        Text(CurrencyFormatter.formatPercent(quote.changePercent))
                            .font(.caption)
                            .foregroundStyle(quote.isPositive ? .green : .red)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
