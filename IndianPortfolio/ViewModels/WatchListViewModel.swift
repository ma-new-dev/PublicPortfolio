import Foundation

@MainActor
@Observable
final class WatchListViewModel {
    var quotes: [String: StockQuote] = [:]
    var exchangeRate: Double = 0.0
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private let priceService = StockPriceService()
    @ObservationIgnored private let exchangeService = ExchangeRateService.shared
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    @ObservationIgnored private var trackedItems: [WatchListItem] = []

    func refreshAll(items: [WatchListItem]) async {
        trackedItems = items
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let tickers = items.map(\.ticker)

        async let fetchedQuotes = priceService.fetchQuotes(for: tickers)
        async let fetchedRate = exchangeService.fetchINRToUSD()

        let newQuotes = await fetchedQuotes
        var merged = quotes.filter { tickers.contains($0.key) }
        merged.merge(newQuotes) { _, new in new }
        quotes = merged

        if let rate = try? await fetchedRate {
            exchangeRate = rate
        }

        let missing = tickers.filter { newQuotes[$0] == nil }.count
        errorMessage = missing == 0
            ? nil
            : "Couldn't refresh \(missing) price\(missing == 1 ? "" : "s") — showing last known values."
    }

    func startAutoRefresh(items: [WatchListItem]) {
        trackedItems = items
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                let interval = MarketStatusService.nextRefreshInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                await self.refreshAll(items: self.trackedItems)
            }
        }
    }

    func stopAutoRefresh() {
        refreshLoop?.cancel()
        refreshLoop = nil
    }
}
