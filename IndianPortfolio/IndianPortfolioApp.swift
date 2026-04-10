import SwiftUI
import SwiftData
import AuthenticationServices

@main
struct IndianPortfolioApp: App {
    let container: ModelContainer
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @State private var isSignedIn = false
    @State private var authChecked = false

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
            Group {
                if !authChecked {
                    Color.clear
                        .task { await checkExistingCredential() }
                } else if isSignedIn {
                    mainView
                } else {
                    SignInView {
                        isSignedIn = true
                    }
                }
            }
        }
        .modelContainer(container)
    }

    private var mainView: some View {
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

    private func checkExistingCredential() async {
        #if targetEnvironment(simulator)
        // Skip auth check in simulator for testing
        isSignedIn = true
        authChecked = true
        return
        #endif

        guard !appleUserID.isEmpty else {
            authChecked = true
            isSignedIn = false
            return
        }

        // Verify the credential is still valid with Apple
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: appleUserID)
            isSignedIn = (state == .authorized)
        } catch {
            isSignedIn = false
        }
        authChecked = true
    }
}
