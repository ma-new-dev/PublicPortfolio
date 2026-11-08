import Foundation

/// App-facing wrapper around `MarketDataClient` (shared with the widget).
struct StockPriceService {

    // MARK: - Quotes

    func fetchQuote(for ticker: String) async throws -> StockQuote {
        StockQuote(try await MarketDataClient.fetchQuote(ticker))
    }

    func fetchQuoteIfAvailable(for ticker: String) async -> StockQuote? {
        try? await fetchQuote(for: ticker)
    }

    func fetchQuotes(for tickers: [String]) async -> [String: StockQuote] {
        let quotes = await MarketDataClient.fetchQuotes(tickers)
        return quotes.mapValues { StockQuote($0) }
    }

    // MARK: - Charts

    func fetchChartData(for ticker: String, range: ChartTimeRange) async throws -> ChartDataResult {
        let chart = try await MarketDataClient.fetchChart(
            ticker,
            range: range.yahooRange,
            interval: range.yahooInterval
        )

        var pricePoints: [IntradayDataPoint] = []
        var volumePoints: [VolumeDataPoint] = []
        for point in chart.points {
            if let close = point.close, close > 0 {
                pricePoints.append(IntradayDataPoint(timestamp: point.date, price: close))
            }
            if let volume = point.volume, volume > 0 {
                volumePoints.append(VolumeDataPoint(timestamp: point.date, volume: volume))
            }
        }

        return ChartDataResult(
            pricePoints: pricePoints,
            volumePoints: volumePoints,
            previousClose: chart.previousClose
        )
    }

    // MARK: - Market cap

    func fetchMarketCap(for ticker: String, price: Double? = nil) async -> Double? {
        await MarketDataClient.fetchMarketCap(ticker, price: price)
    }

    // MARK: - Symbol search

    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        let trimmed = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "query1.finance.yahoo.com"
        components.path = "/v1/finance/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "quotesCount", value: "20"),
            URLQueryItem(name: "newsCount", value: "0"),
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }

        let json = try await MarketDataClient.fetchJSON { _ in url }
        guard let quotes = json["quotes"] as? [[String: Any]] else {
            throw ServiceError.parseError
        }

        return quotes.compactMap { quote in
            guard let symbol = quote["symbol"] as? String,
                  MarketDataClient.isValidSymbol(symbol),
                  let name = (quote["longname"] as? String) ?? (quote["shortname"] as? String),
                  let type = quote["quoteType"] as? String,
                  type == "EQUITY",
                  symbol.hasSuffix(".NS") || symbol.hasSuffix(".BO")
            else {
                return nil
            }

            let exchangeName = symbol.hasSuffix(".NS") ? "NSE" : "BSE"
            return SymbolSearchResult(symbol: symbol, name: name, exchange: exchangeName, type: type)
        }
    }
}

extension StockQuote {
    init(_ quote: MarketQuote) {
        self.init(
            id: quote.ticker,
            currentPrice: quote.price,
            previousClose: quote.previousClose,
            change: quote.change,
            changePercent: quote.changePercent,
            marketCap: quote.marketCap,
            lastUpdated: quote.marketTime ?? Date()
        )
    }
}

enum ServiceError: LocalizedError {
    case invalidURL
    case badResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badResponse: return "Bad server response"
        case .parseError: return "Failed to parse data"
        }
    }
}
