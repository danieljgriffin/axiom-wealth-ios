import Foundation

enum AppConfig {
    static let apiBaseURL = "http://192.168.0.90:8000"
    // In a real app, this should come from Keychain or at least not be committed.
    // For this implementation, we read from an environment variable or fallback for ease of testing.
    // Ideally, we'd use a Build Configuration + Info.plist.
    static var apiToken: String {
        return "dev-token-123" // Replace with actual token or read from Keychain
    }
}
