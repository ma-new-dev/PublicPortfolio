import Foundation
import SwiftData
import Combine
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

struct MarketIndex: Identifiable {
    let id: String       // ticker like "^BSESN"
    let name: String     // "SENSEX" or "NIFTY 50"
    let shortName: String // "BSE" or "NSE"
    var value: Double = 0
    var change: Double = 0
    var changePercent: Double = 0
    var isPositive: Bool { change >= 0 }
}

@MainActor
@Observable
final class PortfolioViewModel {
    var quotes: [String: StockQuote] = [:]
    var exchangeRate: Double = 0.0  // INR to USD
    var isLoading = false
    var errorMessage: String?
    var isMarketOpen = false
    var sortOption: SortOption = .valueUSDDesc
    var indices: [MarketIndex] = [
        MarketIndex(id: "^BSESN", name: "SENSEX", shortName: "BSE"),
        MarketIndex(id: "^NSEI", name: "NIFTY 50", shortName: "NSE")
    ]

    private let priceService = StockPriceService()
    private let exchangeService = ExchangeRateService()
    private var refreshTimer: Timer?

    // MARK: - Computed properties

    func totalValueINR(for holdings: [StockHolding]) -> Double {
        holdings.reduce(0) { total, holding in
            let price = quotes[holding.ticker]?.currentPrice ?? 0
            return total + (price * Double(holding.quantity))
        }
    }

    func totalValueUSD(for holdings: [StockHolding]) -> Double {
        guard exchangeRate > 0 else { return 0 }
        return totalValueINR(for: holdings) * exchangeRate
    }

    func holdingValueINR(for holding: StockHolding) -> Double {
        let price = quotes[holding.ticker]?.currentPrice ?? 0
        return price * Double(holding.quantity)
    }

    func holdingValueUSD(for holding: StockHolding) -> Double {
        guard exchangeRate > 0 else { return 0 }
        return holdingValueINR(for: holding) * exchangeRate
    }

    // MARK: - Sorting

    func sortedHoldings(_ holdings: [StockHolding]) -> [StockHolding] {
        holdings.sorted { a, b in
            switch sortOption {
            case .valueUSDDesc:
                return holdingValueUSD(for: a) > holdingValueUSD(for: b)
            case .valueUSDasc:
                return holdingValueUSD(for: a) < holdingValueUSD(for: b)
            case .valueINRDesc:
                return holdingValueINR(for: a) > holdingValueINR(for: b)
            case .valueINRAsc:
                return holdingValueINR(for: a) < holdingValueINR(for: b)
            case .nameAsc:
                return a.companyName.localizedCaseInsensitiveCompare(b.companyName) == .orderedAscending
            case .nameDesc:
                return a.companyName.localizedCaseInsensitiveCompare(b.companyName) == .orderedDescending
            case .changeDesc:
                let aChange = quotes[a.ticker]?.changePercent ?? 0
                let bChange = quotes[b.ticker]?.changePercent ?? 0
                return aChange > bChange
            case .changeAsc:
                let aChange = quotes[a.ticker]?.changePercent ?? 0
                let bChange = quotes[b.ticker]?.changePercent ?? 0
                return aChange < bChange
            }
        }
    }

    // MARK: - Data fetching

    func refreshAll(holdings: [StockHolding]) async {
        isLoading = true
        errorMessage = nil
        isMarketOpen = MarketStatusService.isMarketOpen

        // Always fetch indices and exchange rate, even if no holdings
        let indexTickers = indices.map(\.id)
        let holdingTickers = holdings.map(\.ticker)

        async let fetchedHoldingQuotes = holdingTickers.isEmpty ? [:] : priceService.fetchQuotes(for: holdingTickers)
        async let fetchedIndexQuotes = priceService.fetchQuotes(for: indexTickers)
        async let fetchedRate = exchangeService.fetchINRToUSD()

        let newQuotes = await fetchedHoldingQuotes
        if !newQuotes.isEmpty {
            quotes = newQuotes
        } else if holdingTickers.isEmpty {
            quotes = [:]
        }

        // Update index data
        let indexQuotes = await fetchedIndexQuotes
        for i in indices.indices {
            if let q = indexQuotes[indices[i].id] {
                indices[i].value = q.currentPrice
                indices[i].change = q.change
                indices[i].changePercent = q.changePercent
            }
        }

        do {
            exchangeRate = try await fetchedRate
        } catch {
            if exchangeRate == 0 {
                errorMessage = "Failed to fetch exchange rate"
            }
        }

        isLoading = false

        // Sync data to widget
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

    // MARK: - Auto-refresh timer

    func startAutoRefresh(holdings: [StockHolding]) {
        stopAutoRefresh()
        let interval = MarketStatusService.nextRefreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll(holdings: holdings)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
