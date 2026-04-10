import SwiftUI

struct PortfolioSummaryView: View {
    let totalINR: Double
    let totalUSD: Double
    let exchangeRate: Double
    let isMarketOpen: Bool
    let chartData: [IntradayDataPoint]

    var body: some View {
        VStack(spacing: 16) {
            // Market status
            HStack {
                Circle()
                    .fill(isMarketOpen ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(MarketStatusService.marketStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if exchangeRate > 0 {
                    Text("1 INR = \(String(format: "%.6f", exchangeRate)) USD")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Total values
            VStack(spacing: 6) {
                Text("Portfolio Value")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(CurrencyFormatter.formatINR(totalINR))
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text(CurrencyFormatter.formatUSDMillion(totalUSD))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            // Chart
            PortfolioChartView(dataPoints: chartData)
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}
