import SwiftUI
import AuthenticationServices

struct SignInView: View {
    var onSignIn: () -> Void
    var onSkip: () -> Void

    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon + title
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("IndianPortfolio")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your Indian stock portfolio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 60)

            Spacer()

            // Sign in options
            VStack(spacing: 16) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(10)
                .padding(.horizontal)

                // Guest / skip option — required by App Store guideline 5.1.1(v)
                Button {
                    onSkip()
                } label: {
                    Text("Continue without signing in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }

                Text("Sign in with Apple enables iCloud sync across your devices.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }

    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                UserDefaults.standard.set(userID, forKey: "appleUserID")
                onSignIn()
            }
        case .failure(let error):
            // User cancelled sign-in — don't show error
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
}
