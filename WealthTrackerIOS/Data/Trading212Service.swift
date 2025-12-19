import Foundation

struct Trading212Position: Codable {
    let ticker: String
    let quantity: Double
    let averagePrice: Double
    let currentPrice: Double
    let ppl: Double // Profit/Loss
    let fxPpl: Double? // FX Profit/Loss
    let initialFillDate: String?
    let maxBuy: Double?
    let maxSell: Double?
    let pieId: Double?
    
    // Helper to get total value
    var value: Double {
        return quantity * currentPrice
    }
}

class Trading212Service {
    private let baseURL = "https://live.trading212.com/api/v0"
    
    func fetchPortfolio(apiKey: String, apiSecret: String) async throws -> [Trading212Position] {
        guard let url = URL(string: "\(baseURL)/equity/portfolio") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let loginString = "\(apiKey):\(apiSecret)"
        guard let loginData = loginString.data(using: .utf8) else {
            throw URLError(.userAuthenticationRequired)
        }
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 {
            throw Trading212Error.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw Trading212Error.apiError(statusCode: httpResponse.statusCode, message: "Portfolio Error: \(body)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Trading212Position].self, from: data)
    }
    
    func fetchInstrumentMetadata(apiKey: String, apiSecret: String) async throws -> [Trading212Instrument] {
        guard let url = URL(string: "\(baseURL)/equity/metadata/instruments") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let loginString = "\(apiKey):\(apiSecret)"
        guard let loginData = loginString.data(using: .utf8) else {
            throw URLError(.userAuthenticationRequired)
        }
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 {
             throw Trading212Error.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw Trading212Error.apiError(statusCode: httpResponse.statusCode, message: "Metadata Error: \(body)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Trading212Instrument].self, from: data)
    }
}

enum Trading212Error: LocalizedError {
    case unauthorized
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API Key or Secret. Please check your credentials."
        case .apiError(let statusCode, let message):
            return "Trading 212 Error (\(statusCode)): \(message)"
        }
    }
}

struct Trading212Instrument: Codable {
    let ticker: String
    let name: String
    let currencyCode: String
    let shortName: String?
}
