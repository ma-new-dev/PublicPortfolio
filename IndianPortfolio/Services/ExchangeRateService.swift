import Foundation

actor ExchangeRateService {
    private var cachedRate: Double?
    private var lastFetchTime: Date?

    func fetchINRToUSD() async throws -> Double {
        // Return cached rate if less than 1 hour old
        if let cached = cachedRate,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < AppConstants.exchangeRateCacheSeconds {
            return cached
        }

        guard let url = URL(string: AppConstants.API.exchangeRateURL) else {
            throw ServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // Fall back to cached rate if available
            if let cached = cachedRate { return cached }
            throw ServiceError.badResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = json["rates"] as? [String: Double],
              let usdRate = rates["USD"]
        else {
            if let cached = cachedRate { return cached }
            throw ServiceError.parseError
        }

        cachedRate = usdRate
        lastFetchTime = Date()
        return usdRate
    }
}
