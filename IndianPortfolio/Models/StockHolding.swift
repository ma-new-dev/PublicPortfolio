import Foundation
import SwiftData

@Model
final class StockHolding {
    var id: UUID = UUID()
    var ticker: String = ""        // e.g. "RELIANCE.NS" or "RELIANCE.BO"
    var companyName: String = ""
    var exchange: String = ""      // "NSE" or "BSE"
    var quantity: Int = 0
    var dateAdded: Date = Date()

    init(ticker: String, companyName: String, exchange: String, quantity: Int) {
        self.id = UUID()
        self.ticker = ticker
        self.companyName = companyName
        self.exchange = exchange
        self.quantity = quantity
        self.dateAdded = Date()
    }
}
