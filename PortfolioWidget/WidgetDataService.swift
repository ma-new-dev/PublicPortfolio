import Foundation

struct WidgetQuote {
    let currentPrice: Double
    let changePercent: Double
    let isPositive: Bool
    let marketTime: Date?
}

/// Widget-side data fetching. Uses the same `MarketDataClient` as the app so
/// the widget and app always agree on prices, day change and FX.
enum WidgetDataService {

    static func fetchQuotes(for tickers: [String]) async -> [String: WidgetQuote] {
        let quotes = await MarketDataClient.fetchQuotes(tickers)
        return quotes.mapValues { q in
            WidgetQuote(
                currentPrice: q.price,
                changePercent: q.changePercent,
                isPositive: q.isPositive,
                marketTime: q.marketTime
            )
        }
    }

    /// US dollars per rupee. Falls back to the last rate saved by the app (or a
    /// previous widget run) instead of returning 0 and showing $0.00.
    static func fetchExchangeRate() async -> Double {
        if let rate = try? await MarketDataClient.fetchUSDPerINR(), rate > 0 {
            PortfolioDataStore.saveExchangeRate(rate)
            return rate
        }
        return PortfolioDataStore.loadExchangeRate()?.rate ?? 0
    }

    static func fetchIndices() async -> [WidgetIndex] {
        let definitions = [("^NSEI", "NIFTY 50"), ("^BSESN", "SENSEX")]
        let quotes = await fetchQuotes(for: definitions.map { $0.0 })
        // Keep a stable, explicit order.
        return definitions.compactMap { ticker, name in
            guard let q = quotes[ticker] else { return nil }
            return WidgetIndex(
                id: ticker,
                name: name,
                value: q.currentPrice,
                changePercent: q.changePercent,
                isPositive: q.isPositive
            )
        }
    }
}
