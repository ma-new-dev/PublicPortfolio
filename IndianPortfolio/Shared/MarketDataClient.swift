import Foundation

// MARK: - Models

/// A normalised live quote. Shared by the app and the widget so both show the
/// same numbers.
struct MarketQuote: Sendable {
    let ticker: String
    /// Latest traded / index value.
    let price: Double
    /// Official close of the previous trading session.
    let previousClose: Double
    /// Time of the latest trade reported by the exchange.
    let marketTime: Date?
    let marketCap: Double?

    var change: Double { price - previousClose }
    var changePercent: Double { previousClose > 0 ? (change / previousClose) * 100 : 0 }
    var isPositive: Bool { change >= 0 }
}

/// Raw chart series for a symbol over a range.
struct MarketChart: Sendable {
    struct Point: Sendable {
        let date: Date
        let close: Double?
        let volume: Double?
    }

    let points: [Point]
    /// Close immediately before the first point of the range (Yahoo's
    /// `chartPreviousClose`). This is the right baseline for "change over the range".
    let previousClose: Double?
    /// Latest live price from the chart metadata.
    let regularMarketPrice: Double?
}

enum MarketDataError: LocalizedError {
    case invalidSymbol
    case badResponse(Int)
    case parseError
    case implausibleValue

    var errorDescription: String? {
        switch self {
        case .invalidSymbol: return "Invalid symbol"
        case .badResponse(let code): return code > 0 ? "Server returned \(code)" : "Bad server response"
        case .parseError: return "Failed to parse market data"
        case .implausibleValue: return "Received an implausible value"
        }
    }
}

// MARK: - Client

/// Thin, stateless client for Yahoo Finance's public chart endpoints.
///
/// Why this exists:
/// * The old code computed day change from `chartPreviousClose` of a 1-minute
///   intraday chart. For NSE/BSE that value is the *last traded price* of the
///   previous session, not the *official close* (NSE/BSE close = VWAP of the last
///   30 minutes), so index and stock % changes were frequently off.
///   We now take the previous close from the official daily bars.
/// * Exchange rate came from a free feed that only updates once per day; we now
///   use the live USD/INR quote (`INR=X`) with that feed only as a fallback.
/// * Symbols are validated and percent-encoded before going into a URL.
enum MarketDataClient {

    static let indiaTimeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current

    private static let hosts = ["query1.finance.yahoo.com", "query2.finance.yahoo.com"]
    static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        // Market data must never come from a stale HTTP cache.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.waitsForConnectivity = false
        // Yahoo's crumb flow relies on a cookie set by fc.yahoo.com.
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    // MARK: Symbol validation

    private static let allowedSymbolCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.^=&-_"
    )
    private static let pathSafeCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_"
    )

    /// Yahoo symbols are short ASCII strings like `RELIANCE.NS`, `M&M.NS`, `^NSEI`, `INR=X`.
    /// Anything else (slashes, query characters, unicode) is rejected so it can't
    /// alter the request path.
    static func isValidSymbol(_ symbol: String) -> Bool {
        guard !symbol.isEmpty, symbol.count <= 32 else { return false }
        return symbol.unicodeScalars.allSatisfy { allowedSymbolCharacters.contains($0) }
    }

    // MARK: Public API

    /// Live quote with previous close taken from official daily bars.
    static func fetchQuote(_ symbol: String) async throws -> MarketQuote {
        let json = try await fetchJSON { host in
            chartURL(host: host, symbol: symbol, range: "5d", interval: "1d")
        }
        let result = try chartResult(json)
        guard let meta = result["meta"] as? [String: Any],
              let price = number(meta["regularMarketPrice"]), price > 0
        else { throw MarketDataError.parseError }

        let marketTime = number(meta["regularMarketTime"]).map { Date(timeIntervalSince1970: $0) }
        let timeZone = (meta["exchangeTimezoneName"] as? String).flatMap(TimeZone.init(identifier:))
            ?? indiaTimeZone

        let bars = parsePoints(result).compactMap { p -> (Date, Double)? in
            guard let c = p.close, c > 0 else { return nil }
            return (p.date, c)
        }

        let fromBars = previousSessionClose(
            bars: bars,
            marketTime: marketTime ?? Date(),
            timeZone: timeZone
        )
        guard let previousClose = fromBars
                ?? number(meta["previousClose"])
                ?? number(meta["chartPreviousClose"]),
              previousClose > 0
        else { throw MarketDataError.parseError }

        return MarketQuote(
            ticker: symbol,
            price: price,
            previousClose: previousClose,
            marketTime: marketTime,
            marketCap: number(meta["marketCap"])
        )
    }

    /// Fetch many quotes concurrently. Failed symbols are simply absent.
    static func fetchQuotes(_ symbols: [String]) async -> [String: MarketQuote] {
        let unique = Array(Set(symbols))
        var results: [String: MarketQuote] = [:]
        await withTaskGroup(of: (String, MarketQuote?).self) { group in
            for symbol in unique {
                group.addTask { (symbol, try? await fetchQuote(symbol)) }
            }
            for await (symbol, quote) in group {
                if let quote { results[symbol] = quote }
            }
        }
        return results
    }

    /// Chart series for a range.
    static func fetchChart(_ symbol: String, range: String, interval: String) async throws -> MarketChart {
        let json = try await fetchJSON { host in
            chartURL(host: host, symbol: symbol, range: range, interval: interval)
        }
        let result = try chartResult(json)
        let meta = result["meta"] as? [String: Any] ?? [:]
        return MarketChart(
            points: parsePoints(result),
            previousClose: number(meta["chartPreviousClose"]) ?? number(meta["previousClose"]),
            regularMarketPrice: number(meta["regularMarketPrice"])
        )
    }

    /// US dollars per one Indian rupee (e.g. 0.0114).
    ///
    /// Primary source is the live USD/INR market quote; the once-a-day
    /// open.er-api.com feed is only used if that fails.
    static func fetchUSDPerINR() async throws -> Double {
        if let quote = try? await fetchQuote("INR=X"),
           plausibleINRPerUSD.contains(quote.price) {
            return 1.0 / quote.price
        }

        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            throw MarketDataError.invalidSymbol
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw MarketDataError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = json["rates"] as? [String: Any],
              let inrPerUSD = number(rates["INR"])
        else { throw MarketDataError.parseError }
        guard plausibleINRPerUSD.contains(inrPerUSD) else { throw MarketDataError.implausibleValue }
        return 1.0 / inrPerUSD
    }

    /// Sanity bounds for the USD/INR rate so a bad payload can never silently
    /// mis-value the whole portfolio.
    static let plausibleINRPerUSD: ClosedRange<Double> = 40...250

    // MARK: Previous close

    /// The close of the last daily bar that belongs to a trading day *before*
    /// the day of the latest trade.
    static func previousSessionClose(
        bars: [(Date, Double)],
        marketTime: Date,
        timeZone: TimeZone
    ) -> Double? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let marketDay = calendar.startOfDay(for: marketTime)
        let sorted = bars.sorted { $0.0 < $1.0 }
        let previous = sorted.last(where: { calendar.startOfDay(for: $0.0) < marketDay })
        return previous?.1
    }

    // MARK: Networking helpers

    static func chartURL(host: String, symbol: String, range: String, interval: String) -> URL? {
        guard isValidSymbol(symbol),
              let encoded = symbol.addingPercentEncoding(withAllowedCharacters: pathSafeCharacters)
        else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.percentEncodedPath = "/v8/finance/chart/\(encoded)"
        components.queryItems = [
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "includePrePost", value: "false"),
        ]
        return components.url
    }

    /// GET JSON, trying each Yahoo host in turn.
    static func fetchJSON(_ makeURL: (String) -> URL?) async throws -> [String: Any] {
        var lastError: Error = MarketDataError.badResponse(0)
        for host in hosts {
            guard let url = makeURL(host) else { throw MarketDataError.invalidSymbol }
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw MarketDataError.badResponse(0)
                }
                guard http.statusCode == 200 else {
                    throw MarketDataError.badResponse(http.statusCode)
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw MarketDataError.parseError
                }
                return json
            } catch {
                if Task.isCancelled { throw error }
                lastError = error
            }
        }
        throw lastError
    }

    private static func chartResult(_ json: [String: Any]) throws -> [String: Any] {
        guard let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first
        else { throw MarketDataError.parseError }
        return result
    }

    /// Parse timestamp/close/volume arrays defensively: arrays may contain
    /// `null`s and may differ in length — never index out of bounds.
    private static func parsePoints(_ result: [String: Any]) -> [MarketChart.Point] {
        guard let timestamps = result["timestamp"] as? [Any] else { return [] }
        let indicators = result["indicators"] as? [String: Any]
        let quote = (indicators?["quote"] as? [Any])?.first as? [String: Any]
        let closes = (quote?["close"] as? [Any]) ?? []
        let volumes = (quote?["volume"] as? [Any]) ?? []

        var points: [MarketChart.Point] = []
        points.reserveCapacity(timestamps.count)
        for (i, raw) in timestamps.enumerated() {
            guard let ts = number(raw) else { continue }
            let close = i < closes.count ? number(closes[i]) : nil
            let volume = i < volumes.count ? number(volumes[i]) : nil
            points.append(MarketChart.Point(
                date: Date(timeIntervalSince1970: ts),
                close: close.flatMap { $0.isFinite ? $0 : nil },
                volume: volume.flatMap { $0.isFinite ? $0 : nil }
            ))
        }
        return points
    }

    /// Converts a JSON number (NSNumber) to Double; `null`/other types → nil.
    static func number(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, !(value is NSNull) else { return nil }
        // Exclude JSON booleans, which also bridge to NSNumber.
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
        let d = n.doubleValue
        return d.isFinite ? d : nil
    }
}

// MARK: - Market cap (v7 quote endpoint, needs a cookie + crumb)

/// Yahoo's v7 quote endpoint has required a session crumb since 2023, which is
/// why market cap was usually missing. This fetches one lazily and caches it.
actor YahooCrumbProvider {
    static let shared = YahooCrumbProvider()
    private var crumb: String?

    private func browserRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        // Yahoo refuses the cookie/crumb exchange for non-browser user agents.
        request.setValue(MarketDataClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/json,*/*", forHTTPHeaderField: "Accept")
        return request
    }

    func currentCrumb() async -> String? {
        if let crumb { return crumb }
        let session = MarketDataClient.session
        // 1. Prime the session cookie (fc.yahoo.com answers 404; the cookie is what matters).
        if let primeURL = URL(string: "https://fc.yahoo.com") {
            _ = try? await session.data(for: browserRequest(primeURL))
        }
        // 2. Exchange the cookie for a crumb (try both hosts).
        for host in ["query1.finance.yahoo.com", "query2.finance.yahoo.com"] {
            guard let crumbURL = URL(string: "https://\(host)/v1/test/getcrumb"),
                  let (data, response) = try? await session.data(for: browserRequest(crumbURL)),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let value = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty, value.count < 64,
                  !value.contains("<"), !value.contains(" ")   // e.g. "Too Many Requests"
            else { continue }
            crumb = value
            return value
        }
        return nil
    }

    func invalidate() { crumb = nil }
}

// MARK: - Market cap

/// Shares outstanding per symbol, saved once market cap has been obtained.
/// Market cap is then computed locally as shares × live price, so it keeps
/// working even when Yahoo throttles or blocks its protected endpoints.
enum SharesOutstandingCache {
    private struct Entry: Codable { let shares: Double; let savedAt: Date }
    private static func key(_ symbol: String) -> String { "sharesOutstanding.\(symbol)" }
    static let freshFor: TimeInterval = 7 * 24 * 3600

    static func get(_ symbol: String) -> (shares: Double, isFresh: Bool)? {
        guard let data = UserDefaults.standard.data(forKey: key(symbol)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.shares > 0 else { return nil }
        return (entry.shares, Date().timeIntervalSince(entry.savedAt) < freshFor)
    }

    static func set(_ symbol: String, shares: Double) {
        guard shares > 0, shares.isFinite,
              let data = try? JSONEncoder().encode(Entry(shares: shares, savedAt: Date())) else { return }
        UserDefaults.standard.set(data, forKey: key(symbol))
    }
}

extension MarketDataClient {
    /// Market cap for `symbol`. `price` is the current share price, used to turn
    /// a saved share count into a live market cap.
    ///
    /// Order: fresh saved share count → v7 quote with crumb → v7 without crumb
    /// → chart metadata → fundamentals share count → stale saved share count.
    static func fetchMarketCap(_ symbol: String, price: Double? = nil) async -> Double? {
        guard isValidSymbol(symbol) else { return nil }
        let cached = SharesOutstandingCache.get(symbol)
        if let cached, cached.isFresh, let price, price > 0 {
            return cached.shares * price
        }

        if let cap = await fetchMarketCapFromNetwork(symbol) {
            if let price, price > 0 { SharesOutstandingCache.set(symbol, shares: cap / price) }
            return cap
        }
        if let price, price > 0, let shares = await fetchSharesOutstanding(symbol) {
            SharesOutstandingCache.set(symbol, shares: shares)
            return shares * price
        }
        if let cached, let price, price > 0 {
            return cached.shares * price
        }
        return nil
    }

    private static func fetchMarketCapFromNetwork(_ symbol: String) async -> Double? {
        if let crumb = await YahooCrumbProvider.shared.currentCrumb() {
            if let cap = await requestMarketCap(symbol, host: "query1.finance.yahoo.com", crumb: crumb) {
                return cap
            }
            if let cap = await requestMarketCap(symbol, host: "query2.finance.yahoo.com", crumb: crumb) {
                return cap
            }
            await YahooCrumbProvider.shared.invalidate()
        }
        if let cap = await requestMarketCap(symbol, host: "query1.finance.yahoo.com", crumb: nil) {
            return cap
        }
        // The original v1.0 source: chart metadata of the 1-day/1-minute chart.
        if let json = try? await fetchJSON({ chartURL(host: $0, symbol: symbol, range: "1d", interval: "1m") }),
           let chart = json["chart"] as? [String: Any],
           let result = (chart["result"] as? [[String: Any]])?.first,
           let meta = result["meta"] as? [String: Any],
           let cap = number(meta["marketCap"]), cap > 0 {
            return cap
        }
        return nil
    }

    private static func requestMarketCap(_ symbol: String, host: String, crumb: String?) async -> Double? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/v7/finance/quote"
        var items = [
            URLQueryItem(name: "symbols", value: symbol),
            URLQueryItem(name: "fields", value: "marketCap"),
        ]
        if let crumb { items.append(URLQueryItem(name: "crumb", value: crumb)) }
        components.queryItems = items
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quoteResponse = json["quoteResponse"] as? [String: Any],
              let results = quoteResponse["result"] as? [[String: Any]],
              let cap = number(results.first?["marketCap"]),
              cap > 0
        else { return nil }
        return cap
    }

    /// Latest reported share count from Yahoo's fundamentals time series.
    private static func fetchSharesOutstanding(_ symbol: String) async -> Double? {
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: pathSafeCharacters) else { return nil }
        let types = ["quarterlyOrdinarySharesNumber", "annualOrdinarySharesNumber"]
        let now = Int(Date().timeIntervalSince1970)
        guard let json = try? await fetchJSON({ host in
            var c = URLComponents()
            c.scheme = "https"
            c.host = host
            c.percentEncodedPath = "/ws/fundamentals-timeseries/v1/finance/timeseries/\(encoded)"
            c.queryItems = [
                URLQueryItem(name: "type", value: types.joined(separator: ",")),
                URLQueryItem(name: "period1", value: String(now - 3 * 365 * 24 * 3600)),
                URLQueryItem(name: "period2", value: String(now)),
            ]
            return c.url
        }),
              let timeseries = json["timeseries"] as? [String: Any],
              let results = timeseries["result"] as? [[String: Any]]
        else { return nil }

        for type in types {
            for result in results {
                guard let series = result[type] as? [Any] else { continue }
                let values = series.compactMap { entry -> Double? in
                    guard let dict = entry as? [String: Any],
                          let reported = dict["reportedValue"] as? [String: Any] else { return nil }
                    return number(reported["raw"])
                }
                if let latest = values.last, latest > 0 { return latest }
            }
        }
        return nil
    }
}
