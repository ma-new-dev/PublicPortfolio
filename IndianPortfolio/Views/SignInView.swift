import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon + title
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("ECM Portfolio")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your Indian stock portfolio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        let userID = credential.user
                        UserDefaults.standard.set(userID, forKey: "appleUserID")
                        onSignIn()
                    }
                case .failure:
                    break
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 32)
        }
        .padding()
    }
}
