import SwiftUI

struct StockRowView: View {
    let holding: StockHolding
    let quote: StockQuote?
    let exchangeRate: Double

    private var holdingValueINR: Double {
        (quote?.currentPrice ?? 0) * Double(holding.quantity)
    }

    private var holdingValueUSD: Double {
        guard exchangeRate > 0 else { return 0 }
        return holdingValueINR * exchangeRate
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: Company info
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.companyName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(holding.ticker)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(CurrencyFormatter.formatSharesMillions(holding.quantity)) shares")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Right: Price info
            if let quote {
                VStack(alignment: .trailing, spacing: 4) {
                    // Share price + % change (MOST visible)
                    HStack(spacing: 6) {
                        Text(CurrencyFormatter.formatINR(quote.currentPrice))
                            .font(.headline)

                        Text(CurrencyFormatter.formatPercent(quote.changePercent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(quote.isPositive ? .green : .red)
                    }

                    // USD million value (medium visibility)
                    Text(CurrencyFormatter.formatUSDMillion(holdingValueUSD))
                        .font(.subheadline)
                        .foregroundStyle(.blue)

                    // INR crore value (least visible)
                    Text(CurrencyFormatter.formatINRCrore(holdingValueINR))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
