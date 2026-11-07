import SwiftUI

/// Short display forms used in dense lists (the folded cover screen is narrow).
enum DisplayText {
    private static let suffixes = [" Limited", " Ltd.", " Ltd", " LIMITED", " LTD"]

    /// "Reliance Industries Limited" → "Reliance Industries"
    static func company(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespaces)
        for suffix in suffixes where result.hasSuffix(suffix) {
            result = String(result.dropLast(suffix.count))
            break
        }
        return result
    }

    /// "RELIANCE.NS" → "RELIANCE"
    static func symbol(_ ticker: String) -> String {
        if ticker.hasSuffix(".NS") || ticker.hasSuffix(".BO") {
            return String(ticker.dropLast(3))
        }
        return ticker
    }
}

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
        HStack(alignment: .center, spacing: 10) {
            // Left: name + symbol. Takes the leftover width and truncates
            // rather than wrapping.
            VStack(alignment: .leading, spacing: 3) {
                Text(DisplayText.company(holding.companyName))
                    .font(.headline)
                    .truncationMode(.tail)

                Text("\(DisplayText.symbol(holding.ticker)) · \(CurrencyFormatter.formatSharesMillions(holding.quantity)) sh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: numbers. Sized to fit, never wraps.
            if let quote {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(CurrencyFormatter.formatINR(quote.currentPrice))
                            .font(.headline)
                        Text(CurrencyFormatter.formatPercent(quote.changePercent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(quote.isPositive ? .green : .red)
                    }

                    HStack(spacing: 6) {
                        Text(CurrencyFormatter.formatUSDMillion(holdingValueUSD))
                            .foregroundStyle(.blue)
                        Text(CurrencyFormatter.formatINRCrore(holdingValueINR))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
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
