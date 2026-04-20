import SwiftUI
import SwiftData
import AuthenticationServices

struct AccountSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appleUserID") private var appleUserID: String = ""

    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var isDeleting = false

    private var isGuest: Bool { appleUserID == "guest" }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Account Info
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: isGuest ? "person.circle" : "applelogo")
                            .font(.system(size: 38))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isGuest ? "Guest User" : "Apple Account")
                                .font(.headline)
                            Text(isGuest
                                 ? "Using app without an account"
                                 : "Signed in with Apple")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - iCloud Data
                Section("Data") {
                    Label {
                        Text("Portfolio and watch list data syncs across your devices via iCloud.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.blue)
                    }
                }

                // MARK: - Sign Out
                Section {
                    Button {
                        showingSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.primary)
                    }
                }

                // MARK: - Delete Account
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Account & All Data",
                              systemImage: "person.crop.circle.badge.minus")
                    }
                } footer: {
                    Text("Permanently deletes all portfolio holdings and watch list items from this device and iCloud. This action cannot be undone.")
                        .font(.caption)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            // Sign Out confirmation
            .confirmationDialog(
                "Sign Out?",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) { signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data will remain on this device and in iCloud.")
            }
            // Delete Account confirmation
            .confirmationDialog(
                "Delete Account & All Data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All portfolio holdings and watch list items will be permanently deleted. This cannot be undone.")
            }
            // Deleting overlay
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView().tint(.white)
                            Text("Deleting account…")
                                .foregroundStyle(.white)
                                .font(.subheadline)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func signOut() {
        appleUserID = ""
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        dismiss()
    }

    private func deleteAccount() async {
        isDeleting = true

        // 1. Delete all SwiftData records (holdings + watch list)
        do {
            try modelContext.delete(model: StockHolding.self)
            try modelContext.delete(model: WatchListItem.self)
            try modelContext.save()
        } catch {
            // Continue with sign-out even if deletion fails
        }

        // 2. Clear shared App Group cache used by the widget
        if let sharedDefaults = UserDefaults(suiteName: "group.com.portfolio.IndianPortfolio") {
            sharedDefaults.removePersistentDomain(forName: "group.com.portfolio.IndianPortfolio")
        }

        // 3. Clear auth state
        appleUserID = ""

        isDeleting = false
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        dismiss()
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let userDidSignOut = Notification.Name("com.portfolio.IndianPortfolio.userDidSignOut")
}
