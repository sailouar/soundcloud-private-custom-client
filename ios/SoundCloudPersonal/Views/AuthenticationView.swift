import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var coordinator: AuthenticationCoordinator

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SoundCloud Personal")
                        .font(.headline)
                    Text("Private client for your own account. Passwords are never entered or stored.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.state {
        case .needsConfiguration:
            configurationSection
        case .restoring:
            Section {
                ProgressView("Restoring session…")
            }
        case .signedOut:
            signInSection
        case .authorizing:
            Section {
                ProgressView("Waiting for SoundCloud…")
            }
        case .signedIn:
            signedInSection
        case .failed(let message):
            failureSection(message)
        }
    }

    private var configurationSection: some View {
        Section {
            TextField("Client ID", text: $coordinator.clientIDInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Client secret", text: $coordinator.clientSecretInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Save configuration") {
                Task { await coordinator.saveCredentials() }
            }
            .disabled(!coordinator.canSaveConfiguration)
        } header: {
            Text("SoundCloud app")
        } footer: {
            Text("Create a developer app at soundcloud.com/you/apps and register the redirect address soundcloudpersonal://oauth/callback. Both values stay in this device's Keychain.")
        }
    }

    private var signInSection: some View {
        Section {
            Button {
                Task { await coordinator.signIn() }
            } label: {
                Label("Sign in with SoundCloud", systemImage: "person.badge.key")
            }
            Button("Reset app configuration", role: .destructive) {
                Task { await coordinator.resetCredentials() }
            }
        } footer: {
            Text("SoundCloud opens in the system browser session. The app receives only the authorization code.")
        }
    }

    private var signedInSection: some View {
        Section {
            Label("Signed in to SoundCloud", systemImage: "checkmark.seal")
            Button("Sign out", role: .destructive) {
                Task { await coordinator.signOut() }
            }
        } footer: {
            Text("Session tokens are stored in this device's Keychain.")
        }
    }

    private func failureSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
            Button("Try again") {
                Task { await coordinator.retry() }
            }
        } header: {
            Text("Sign-in problem")
        }
    }
}
