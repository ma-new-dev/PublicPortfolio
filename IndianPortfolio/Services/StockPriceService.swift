import Foundation

actor StockPriceService {

    // MARK: - Fetch live quote for a single ticker

    func fetchQuote(for ticker: String) async throws -> StockQuote {
        let urlString = "\(AppConstants.API.yahooChartBase)/\(ticker)?interval=1m&range=1d"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.badResponse
        }

        return try parseChartResponse(data: data, ticker: ticker)
    }

    // MARK: - Fetch quotes for multiple tickers

    func fetchQuotes(for tickers: [String]) async -> [String: StockQuote] {
        var results: [String: StockQuote] = [:]
        await withTaskGroup(of: (String, StockQuote?).self) { group in
            for ticker in tickers {
                group.addTask {
                    let quote = try? await self.fetchQuote(for: ticker)
                    return (ticker, quote)
                }
            }
            for await (ticker, quote) in group {
                if let quote {
                    results[ticker] = quote
                }
            }
        }
        return results
    }

    // MARK: - Fetch intraday data for charting (portfolio-level, kept for backward compat)

    func fetchIntradayData(for ticker: String) async throws -> [IntradayDataPoint] {
        let result = try await fetchChartData(for: ticker, range: .oneDay)
        return result.pricePoints
    }

    // MARK: - Fetch chart data for a given time range (price + volume)

    func fetchChartData(for ticker: String, range: ChartTimeRange) async throws -> ChartDataResult {
        let urlString = "\(AppConstants.API.yahooChartBase)/\(ticker)?interval=\(range.yahooInterval)&range=\(range.yahooRange)"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.badResponse
        }

        return try parseChartDataWithVolume(data: data)
    }

    // MARK: - Symbol search

    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(AppConstants.API.yahooSearchBase)?q=\(encoded)&quotesCount=15&newsCount=0"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseSearchResults(data: data)
    }

    // MARK: - JSON Parsing

    private func parseChartResponse(data: Data, ticker: String) throws -> StockQuote {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let meta = result["meta"] as? [String: Any],
              let regularMarketPrice = meta["regularMarketPrice"] as? Double,
              let previousClose = meta["chartPreviousClose"] as? Double
        else {
            throw ServiceError.parseError
        }

        let change = regularMarketPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
        let marketCap = meta["marketCap"] as? Double

        return StockQuote(
            id: ticker,
            currentPrice: regularMarketPrice,
            previousClose: previousClose,
            change: change,
            changePercent: changePercent,
            marketCap: marketCap,
            lastUpdated: Date()
        )
    }

    private func parseChartDataWithVolume(data: Data) throws -> ChartDataResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let timestamps = result["timestamp"] as? [Int],
              let indicators = result["indicators"] as? [String: Any],
              let quotes = indicators["quote"] as? [[String: Any]],
              let quote = quotes.first,
              let closes = quote["close"] as? [Double?]
        else {
            throw ServiceError.parseError
        }

        let volumes = quote["volume"] as? [Double?]

        var pricePoints: [IntradayDataPoint] = []
        var volumePoints: [VolumeDataPoint] = []

        for (index, timestamp) in timestamps.enumerated() {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            if let close = closes[index] {
                pricePoints.append(IntradayDataPoint(timestamp: date, price: close))
            }
            if let volumes = volumes, let vol = volumes[index] {
                volumePoints.append(VolumeDataPoint(timestamp: date, volume: vol))
            }
        }

        return ChartDataResult(pricePoints: pricePoints, volumePoints: volumePoints)
    }

    private func parseSearchResults(data: Data) throws -> [SymbolSearchResult] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotes = json["quotes"] as? [[String: Any]]
        else {
            throw ServiceError.parseError
        }

        return quotes.compactMap { quote in
            guard let symbol = quote["symbol"] as? String,
                  let name = (quote["longname"] as? String) ?? (quote["shortname"] as? String),
                  let exchange = quote["exchange"] as? String,
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
