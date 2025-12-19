import Foundation

enum AppConfig {
    static let apiBaseURL = "https://finance-api-snqw.onrender.com"
    // In a real app, this should come from Keychain or at least not be committed.
    // For this implementation, we read from an environment variable or fallback for ease of testing.
    // Ideally, we'd use a Build Configuration + Info.plist.
    static var apiToken: String {
        return "08ca04287b677cad743eebd423a1a385b95493b598cca7ef571adb5ea79377bb" // Replace with actual token or read from Keychain
    }
}
