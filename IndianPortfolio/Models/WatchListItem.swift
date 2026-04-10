import Foundation
import SwiftData

@Model
final class WatchListItem {
    var id: UUID = UUID()
    var ticker: String = ""
    var companyName: String = ""
    var exchange: String = ""
    var dateAdded: Date = Date()

    init(ticker: String, companyName: String, exchange: String) {
        self.id = UUID()
        self.ticker = ticker
        self.companyName = companyName
        self.exchange = exchange
        self.dateAdded = Date()
    }
}
