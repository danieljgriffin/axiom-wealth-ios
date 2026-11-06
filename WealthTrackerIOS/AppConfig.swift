import Foundation

enum AppConfig {
    #if !DEBUG || !targetEnvironment(simulator)
    static let apiBaseURL = "https://finance-api-snqw.onrender.com"
    static let apiToken: String = {
        guard let url = Bundle.main.url(forResource: "LocalAPI", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let config = try? PropertyListDecoder().decode(LocalAPI.self, from: data) else { return "" }
        return config.apiToken
    }()

    private struct LocalAPI: Decodable {
        let apiToken: String
    }
    #else
    static let apiBaseURL = "http://localhost:8017"
    static let apiToken = "dev-token-123"
    #endif
}
