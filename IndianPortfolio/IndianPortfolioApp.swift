import SwiftUI
import SwiftData

@main
struct IndianPortfolioApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([StockHolding.self, WatchListItem.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                PortfolioView()
                    .tabItem {
                        Label("Portfolio", systemImage: "briefcase.fill")
                    }

                WatchListView()
                    .tabItem {
                        Label("Watch List", systemImage: "eye.fill")
                    }
            }
        }
        .modelContainer(container)
    }
}
