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

enum PortfolioDataStore {
    static let suiteName = "group.com.portfolio.IndianPortfolio"

    static func save(holdings: [SharedHolding]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let data = SharedPortfolioData(holdings: holdings, lastUpdated: Date())
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: "portfolioData")
        }
    }

    static func load() -> SharedPortfolioData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "portfolioData") else { return nil }
        return try? JSONDecoder().decode(SharedPortfolioData.self, from: data)
    }
}
