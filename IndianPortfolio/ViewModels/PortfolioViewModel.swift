import Foundation
import SwiftData
import WidgetKit

enum SortOption: String, CaseIterable, Identifiable {
    case valueUSDDesc = "Value (USD) ↓"
    case valueUSDasc = "Value (USD) ↑"
    case valueINRDesc = "Value (INR) ↓"
    case valueINRAsc = "Value (INR) ↑"
    case nameAsc = "Name A→Z"
    case nameDesc = "Name Z→A"
    case changeDesc = "Day Change ↓"
    case changeAsc = "Day Change ↑"

    var id: String { rawValue }
}

struct MarketIndex: Identifiable, Hashable {
    let id: String       // ticker like "^BSESN"
    let name: String     // "SENSEX" or "NIFTY 50"
    let shortName: String // "BSE" or "NSE"
    var value: Double = 0
    var change: Double = 0
    var changePercent: Double = 0
    var previousClose: Double = 0
    var lastUpdated: Date?
    var isPositive: Bool { change >= 0 }

    mutating func apply(_ quote: StockQuote) {
        value = quote.currentPrice
        change = quote.change
        changePercent = quote.changePercent
        previousClose = quote.previousClose
        lastUpdated = quote.lastUpdated
    }

    static let defaults: [MarketIndex] = [
        MarketIndex(id: "^NSEI", name: "NIFTY 50", shortName: "NSE"),
        MarketIndex(id: "^BSESN", name: "SENSEX", shortName: "BSE"),
    ]
}

@MainActor
@Observable
final class PortfolioViewModel {
    var quotes: [String: StockQuote] = [:]
    var exchangeRate: Double = 0.0  // USD per INR
    var isLoading = false
    var errorMessage: String?
    var isMarketOpen = false
    var lastRefreshed: Date?
    var sortOption: SortOption = .valueUSDDesc
    var indices: [MarketIndex] = MarketIndex.defaults

    private static let sortKey = "portfolioSortOption"
    @ObservationIgnored private let priceService = StockPriceService()
    @ObservationIgnored private let exchangeService = ExchangeRateService.shared
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    @ObservationIgnored private var trackedHoldings: [StockHolding] = []

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.sortKey),
           let saved = SortOption(rawValue: raw) {
            sortOption = saved
        }
    }

    func persistSortOption() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortKey)
    }

    // MARK: - Computed properties

    func totalValueINR(for holdings: [StockHolding]) -> Double {
        holdings.reduce(0) { $0 + holdingValueINR(for: $1) }
    }

    func totalValueUSD(for holdings: [StockHolding]) -> Double {
        guard exchangeRate > 0 else { return 0 }
        return totalValueINR(for: holdings) * exchangeRate
    }

    /// Portfolio day change in INR, from previous close to now.
    func dayChangeINR(for holdings: [StockHolding]) -> Double {
        holdings.reduce(0) { total, holding in
            guard let q = quotes[holding.ticker] else { return total }
            return total + q.change * Double(holding.quantity)
        }
    }

    func dayChangePercent(for holdings: [StockHolding]) -> Double {
        let previousValue = holdings.reduce(0.0) { total, holding in
            guard let q = quotes[holding.ticker] else { return total }
            return total + q.previousClose * Double(holding.quantity)
        }
        guard previousValue > 0 else { return 0 }
        return dayChangeINR(for: holdings) / previousValue * 100
    }

    func holdingValueINR(for holding: StockHolding) -> Double {
        let price = quotes[holding.ticker]?.currentPrice ?? 0
        return price * Double(holding.quantity)
    }

    func holdingValueUSD(for holding: StockHolding) -> Double {
        guard exchangeRate > 0 else { return 0 }
        return holdingValueINR(for: holding) * exchangeRate
    }

    func weight(of holding: StockHolding, in holdings: [StockHolding]) -> Double {
        let total = totalValueINR(for: holdings)
        guard total > 0 else { return 0 }
        return holdingValueINR(for: holding) / total * 100
    }

    // MARK: - Sorting

    func sortedHoldings(_ holdings: [StockHolding]) -> [StockHolding] {
        holdings.sorted { a, b in
            switch sortOption {
            case .valueUSDDesc, .valueINRDesc:
                return holdingValueINR(for: a) > holdingValueINR(for: b)
            case .valueUSDasc, .valueINRAsc:
                return holdingValueINR(for: a) < holdingValueINR(for: b)
            case .nameAsc:
                return a.companyName.localizedCaseInsensitiveCompare(b.companyName) == .orderedAscending
            case .nameDesc:
                return a.companyName.localizedCaseInsensitiveCompare(b.companyName) == .orderedDescending
            case .changeDesc:
                return (quotes[a.ticker]?.changePercent ?? 0) > (quotes[b.ticker]?.changePercent ?? 0)
            case .changeAsc:
                return (quotes[a.ticker]?.changePercent ?? 0) < (quotes[b.ticker]?.changePercent ?? 0)
            }
        }
    }

    // MARK: - Data fetching

    func refreshAll(holdings: [StockHolding]) async {
        trackedHoldings = holdings
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let indexTickers = indices.map(\.id)
        let holdingTickers = holdings.map(\.ticker)

        async let fetchedHoldingQuotes = priceService.fetchQuotes(for: holdingTickers)
        async let fetchedIndexQuotes = priceService.fetchQuotes(for: indexTickers)
        async let fetchedRate = exchangeService.fetchINRToUSD()

        // Merge new quotes over old ones so a single failed request doesn't
        // blank a holding (and drop it from the portfolio total).
        let newQuotes = await fetchedHoldingQuotes
        var merged = quotes.filter { holdingTickers.contains($0.key) }
        merged.merge(newQuotes) { _, new in new }
        quotes = merged

        let indexQuotes = await fetchedIndexQuotes
        for i in indices.indices {
            if let q = indexQuotes[indices[i].id] {
                indices[i].apply(q)
            }
        }

        var problems: [String] = []
        do {
            exchangeRate = try await fetchedRate
        } catch {
            if exchangeRate == 0 { problems.append("exchange rate") }
        }

        let missing = holdingTickers.filter { newQuotes[$0] == nil }
        if !missing.isEmpty {
            problems.append(missing.count == holdingTickers.count
                            ? "prices"
                            : "\(missing.count) price\(missing.count == 1 ? "" : "s")")
        }
        if indexQuotes.isEmpty { problems.append("indices") }
        errorMessage = problems.isEmpty
            ? nil
            : "Couldn't refresh \(problems.joined(separator: ", ")) — showing last known values."

        let latestTrade = indices.compactMap(\.lastUpdated).max()
        isMarketOpen = MarketStatusService.isMarketOpen(lastTradeTime: latestTrade)
        if !newQuotes.isEmpty || !indexQuotes.isEmpty {
            lastRefreshed = latestTrade ?? Date()
        }

        notifyWidget(holdings: holdings)
    }

    // MARK: - Widget sync

    func notifyWidget(holdings: [StockHolding]) {
        let shared = holdings.map {
            SharedHolding(
                ticker: $0.ticker,
                companyName: $0.companyName,
                exchange: $0.exchange,
                quantity: $0.quantity
            )
        }
        PortfolioDataStore.save(holdings: shared)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Auto-refresh

    /// Starts a refresh loop whose cadence follows the market clock (15s while
    /// open, 5 min otherwise). Always refreshes the latest holdings list.
    func startAutoRefresh(holdings: [StockHolding]) {
        trackedHoldings = holdings
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                let interval = MarketStatusService.nextRefreshInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                await self.refreshAll(holdings: self.trackedHoldings)
            }
        }
    }

    func stopAutoRefresh() {
        refreshLoop?.cancel()
        refreshLoop = nil
    }
}
