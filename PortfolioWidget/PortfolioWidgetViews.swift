import SwiftUI
import WidgetKit

struct PortfolioWidgetEntryView: View {
    var entry: PortfolioEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: PortfolioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("ECM")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Circle()
                    .fill(entry.isMarketOpen ? .green : .red)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // Portfolio total
            if entry.totalValueINR > 0 {
                Text(formatINRCrore(entry.totalValueINR))
                    .font(.title3)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.7)

                Text(formatUSDMillion(entry.totalValueUSD))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)
            } else {
                Text("No Holdings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Indices summary
            if let sensex = entry.indices.first(where: { $0.name == "SENSEX" }) {
                HStack(spacing: 4) {
                    Text("SENSEX")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatPercent(sensex.changePercent))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(sensex.isPositive ? .green : .red)
                }
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: PortfolioEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Portfolio total
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ECM")
                        .font(.headline)
                        .fontWeight(.bold)

                    Circle()
                        .fill(entry.isMarketOpen ? .green : .red)
                        .frame(width: 6, height: 6)
                }

                Spacer()

                if entry.totalValueINR > 0 {
                    Text(formatINRCrore(entry.totalValueINR))
                        .font(.title3)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.7)

                    Text(formatUSDMillion(entry.totalValueUSD))
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }

                // Indices
                ForEach(entry.indices) { index in
                    HStack(spacing: 4) {
                        Text(index.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatPercent(index.changePercent))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(index.isPositive ? .green : .red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Top 3 holdings
            if !entry.holdings.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Holdings")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(entry.holdings.prefix(3)) { holding in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(holding.companyName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(formatINR(holding.currentPrice))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formatPercent(holding.changePercent))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(holding.isPositive ? .green : .red)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: PortfolioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text("ECM")
                    .font(.headline)
                    .fontWeight(.bold)

                Circle()
                    .fill(entry.isMarketOpen ? .green : .red)
                    .frame(width: 6, height: 6)

                Spacer()

                if entry.exchangeRate > 0 {
                    Text("1 USD = \(String(format: "%.1f", 1.0 / entry.exchangeRate)) INR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Portfolio total
            if entry.totalValueINR > 0 {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatINRCrore(entry.totalValueINR))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(formatUSDMillion(entry.totalValueUSD))
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }

            // Indices row
            if !entry.indices.isEmpty {
                HStack(spacing: 12) {
                    ForEach(entry.indices) { index in
                        HStack(spacing: 6) {
                            Text(index.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(String(format: "%.0f", index.value))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatPercent(index.changePercent))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(index.isPositive ? .green : .red)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
            }

            Divider()

            // Holdings list (top 5)
            if entry.holdings.isEmpty {
                Text("No holdings added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(entry.holdings.prefix(5)) { holding in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holding.companyName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(formatUSDMillion(holding.valueUSD))
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatINR(holding.currentPrice))
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(formatPercent(holding.changePercent))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(holding.isPositive ? .green : .red)
                        }
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Formatting helpers (standalone, no UIKit dependency)

private func formatINRCrore(_ value: Double) -> String {
    let crores = value / 10_000_000
    if crores >= 1 {
        return String(format: "\u{20B9}%.2f Cr", crores)
    } else if crores >= 0.01 {
        return String(format: "\u{20B9}%.4f Cr", crores)
    } else {
        return String(format: "\u{20B9}%.2f", value)
    }
}

private func formatUSDMillion(_ value: Double) -> String {
    let millions = value / 1_000_000
    if millions >= 1 {
        return String(format: "$%.2fM", millions)
    } else if millions >= 0.001 {
        return String(format: "$%.4fM", millions)
    } else {
        return String(format: "$%.2f", value)
    }
}

private func formatINR(_ value: Double) -> String {
    return String(format: "\u{20B9}%.2f", value)
}

private func formatPercent(_ value: Double) -> String {
    let prefix = value >= 0 ? "+" : ""
    return String(format: "%@%.2f%%", prefix, value)
}
