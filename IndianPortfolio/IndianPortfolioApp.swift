import SwiftUI
import SwiftData
import AuthenticationServices

@main
struct IndianPortfolioApp: App {
    let container: ModelContainer
    @AppStorage("appleUserID") private var appleUserID: String = ""
    @State private var isSignedIn = false
    @State private var authChecked = false
    @State private var selectedTab = 0

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
                        // Signed in with Apple
                        isSignedIn = true
                    } onSkip: {
                        // Guest mode — store sentinel so we don't show sign-in again
                        UserDefaults.standard.set("guest", forKey: "appleUserID")
                        isSignedIn = true
                    }
                }
            }
        }
        .modelContainer(container)
    }

    private var mainView: some View {
        TabView(selection: $selectedTab) {
            PortfolioView()
                .tag(0)
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }

            WatchListView()
                .tag(1)
                .tabItem {
                    Label("Watch List", systemImage: "eye.fill")
                }
        }
    }

    private func checkExistingCredential() async {
        #if targetEnvironment(simulator)
        isSignedIn = true
        authChecked = true
        return
        #endif

        // Guest users skip credential check
        if appleUserID == "guest" {
            isSignedIn = true
            authChecked = true
            return
        }

        guard !appleUserID.isEmpty else {
            authChecked = true
            isSignedIn = false
            return
        }

        // Verify the Apple ID credential is still valid
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
