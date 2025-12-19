import Foundation

enum APIError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(Error)
    case unknown(Error)
    case noData
}

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    init() {
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config)
        
        self.jsonDecoder = JSONDecoder()
    }
    
    private var baseURL: String {
        return AppConfig.apiBaseURL
    }
    
    private var token: String {
        return AppConfig.apiToken
    }
    
    func fetch<T: Codable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("API Request: \(request.url?.absoluteString ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(NSError(domain: "Invalid Response", code: 0, userInfo: nil))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("API Error: \(httpResponse.statusCode) - \(body)")
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decoded = try jsonDecoder.decode(T.self, from: data)
            return decoded
        } catch {
            print("Decoding Error for \(endpoint): \(error)")
            throw APIError.decodingError(error)
        }
    }
    
    // Helper to post/put data if needed primarily
    func send<T: Codable, U: Encodable>(_ endpoint: String, method: String = "POST", body: U?) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        print("API \(method): \(request.url?.absoluteString ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(NSError(domain: "Invalid Response", code: 0, userInfo: nil))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("API Error (\(method)): \(httpResponse.statusCode) - \(errorBody)")
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // For empty response interactions (like DELETE returning 204)
        if data.isEmpty {
             // If T is Void or Optional, handle? Swift doesn't make Void Codable easily.
             // We'll rely on calling with a specific type or ignoring return if needed.
             // For now assume all return JSON.
             if T.self == Bool.self { return true as! T } // Hack for void-ish usage
        }
        
        do {
            let decoded = try jsonDecoder.decode(T.self, from: data)
            return decoded
        } catch {
            print("Decoding Error for \(endpoint): \(error)")
            throw APIError.decodingError(error)
        }
    }
}
