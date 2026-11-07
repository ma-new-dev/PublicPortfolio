import Foundation

struct SharedPortfolioData: Codable {
    let holdings: [SharedHolding]
    let lastUpdated: Date
}

struct SharedHolding: Codable {
    let ticker: String
    let companyName: String
    let exchange: String
    let quantity: Int
}

struct StoredExchangeRate: Codable {
    /// US dollars per rupee.
    let rate: Double
    let fetchedAt: Date
}

enum PortfolioDataStore {
    static let suiteName = "group.com.portfolio.IndianPortfolio"
    private static let portfolioKey = "portfolioData"
    private static let exchangeRateKey = "exchangeRate"

    static func save(holdings: [SharedHolding]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let data = SharedPortfolioData(holdings: holdings, lastUpdated: Date())
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: portfolioKey)
        }
    }

    static func load() -> SharedPortfolioData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: portfolioKey) else { return nil }
        return try? JSONDecoder().decode(SharedPortfolioData.self, from: data)
    }

    // MARK: - Last known exchange rate (fallback for app + widget)

    static func saveExchangeRate(_ rate: Double) {
        guard rate > 0, let defaults = UserDefaults(suiteName: suiteName) else { return }
        let stored = StoredExchangeRate(rate: rate, fetchedAt: Date())
        if let encoded = try? JSONEncoder().encode(stored) {
            defaults.set(encoded, forKey: exchangeRateKey)
        }
    }

    /// Returns the last stored rate if it is less than 7 days old.
    static func loadExchangeRate() -> StoredExchangeRate? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: exchangeRateKey),
              let stored = try? JSONDecoder().decode(StoredExchangeRate.self, from: data),
              stored.rate > 0,
              Date().timeIntervalSince(stored.fetchedAt) < 7 * 24 * 3600
        else { return nil }
        return stored
    }

    /// Wipes everything the app shares with the widget (used by Delete Account).
    static func clearAll() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: portfolioKey)
        defaults.removeObject(forKey: exchangeRateKey)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
