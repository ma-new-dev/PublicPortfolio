import Foundation

/// INR→USD conversion with a short cache.
///
/// Uses the live USD/INR market quote (falls back to a daily reference feed).
/// The last good rate is persisted to the shared App Group so the widget can
/// use it if its own fetch fails, instead of showing $0.
actor ExchangeRateService {
    static let shared = ExchangeRateService()

    private var cachedRate: Double?
    private var lastFetchTime: Date?

    /// US dollars per rupee.
    func fetchINRToUSD(forceRefresh: Bool = false) async throws -> Double {
        if !forceRefresh,
           let cached = cachedRate,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < AppConstants.exchangeRateCacheSeconds {
            return cached
        }

        do {
            let rate = try await MarketDataClient.fetchUSDPerINR()
            cachedRate = rate
            lastFetchTime = Date()
            PortfolioDataStore.saveExchangeRate(rate)
            return rate
        } catch {
            if let cached = cachedRate { return cached }
            if let stored = PortfolioDataStore.loadExchangeRate() { return stored.rate }
            throw error
        }
    }
}
