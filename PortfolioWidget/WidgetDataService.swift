import Foundation

struct WidgetQuote {
    let currentPrice: Double
    let changePercent: Double
    let isPositive: Bool
}

enum WidgetDataService {

    // MARK: - Fetch quotes for multiple tickers

    static func fetchQuotes(for tickers: [String]) async -> [String: WidgetQuote] {
        var results: [String: WidgetQuote] = [:]
        await withTaskGroup(of: (String, WidgetQuote?).self) { group in
            for ticker in tickers {
                group.addTask {
                    let quote = try? await fetchQuote(for: ticker)
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

    // MARK: - Fetch single quote

    static func fetchQuote(for ticker: String) async throws -> WidgetQuote {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1m&range=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let meta = result["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double,
              let prevClose = meta["chartPreviousClose"] as? Double
        else { throw URLError(.cannotParseResponse) }

        let change = price - prevClose
        let pct = prevClose > 0 ? (change / prevClose) * 100 : 0
        return WidgetQuote(currentPrice: price, changePercent: pct, isPositive: change >= 0)
    }

    // MARK: - Exchange rate

    static func fetchExchangeRate() async -> Double {
        do {
            guard let url = URL(string: "https://open.er-api.com/v6/latest/INR") else { return 0 }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rates = json["rates"] as? [String: Double],
                  let usdRate = rates["USD"]
            else { return 0 }
            return usdRate
        } catch {
            return 0
        }
    }

    // MARK: - Fetch indices

    static func fetchIndices() async -> [WidgetIndex] {
        let indexTickers = [("^BSESN", "SENSEX"), ("^NSEI", "NIFTY 50")]
        var indices: [WidgetIndex] = []

        await withTaskGroup(of: (String, String, WidgetQuote?).self) { group in
            for (ticker, name) in indexTickers {
                group.addTask {
                    let quote = try? await fetchQuote(for: ticker)
                    return (ticker, name, quote)
                }
            }
            for await (ticker, name, quote) in group {
                if let q = quote {
                    indices.append(WidgetIndex(
                        id: ticker,
                        name: name,
                        value: q.currentPrice,
                        changePercent: q.changePercent,
                        isPositive: q.isPositive
                    ))
                }
            }
        }

        // Sort so SENSEX comes first
        return indices.sorted { $0.id < $1.id }
    }
}
