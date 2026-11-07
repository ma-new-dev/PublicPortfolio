import SwiftUI

struct WatchListRowView: View {
    let item: WatchListItem
    let quote: StockQuote?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayText.company(item.companyName))
                    .font(.headline)
                    .truncationMode(.tail)

                Text("\(DisplayText.symbol(item.ticker)) · \(item.exchange)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let quote {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(CurrencyFormatter.formatINR(quote.currentPrice))
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text(CurrencyFormatter.formatChange(quote.change))
                        Text(CurrencyFormatter.formatPercent(quote.changePercent))
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(quote.isPositive ? .green : .red)
                }
                .lineLimit(1)
                .monospacedDigit()
                .fixedSize()
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
