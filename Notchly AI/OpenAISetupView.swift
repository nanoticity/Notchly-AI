import SwiftUI
import AppKit

struct OpenAISetupView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Set up OpenAI")
                .font(.title)
                .fontWeight(.bold)

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Enter your OpenAI API key")
                .font(.headline)

            Text("Notchly AI uses OpenAI's Chat Completions API. Paste a key from platform.openai.com — it's stored locally on this Mac.")
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            SecureField("sk-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .padding(.horizontal)

            if isValidating {
                ProgressView()
            } else {
                Button("Save & Continue") {
                    validateAndSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(width: 400, height: 340)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        }
    }

    private func validateAndSave() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isValidating = true

        Task {
            let result = await validateKey(trimmed)
            await MainActor.run {
                isValidating = false
                switch result {
                case .success:
                    UserDefaults.standard.set(trimmed, forKey: "openai_api_key")
                    NotificationCenter.default.post(name: NSNotification.Name("OpenAISetupCompleted"), object: nil)
                    isPresented = false
                case .invalidKey:
                    errorMessage = "That API key was rejected by OpenAI (401). Double-check it and try again."
                case .networkError(let message):
                    errorMessage = "Couldn't reach OpenAI: \(message)"
                }
            }
        }
    }

    private enum ValidationResult {
        case success
        case invalidKey
        case networkError(String)
    }

    private func validateKey(_ key: String) async -> ValidationResult {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return .networkError("Invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .networkError("Unexpected response from OpenAI.")
            }
            if http.statusCode == 401 {
                return .invalidKey
            }
            if (200..<300).contains(http.statusCode) {
                return .success
            }
            return .networkError("OpenAI returned status \(http.statusCode).")
        } catch {
            return .networkError(error.localizedDescription)
        }
    }
}
