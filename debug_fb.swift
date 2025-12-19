import Foundation

struct YahooSearchResponse: Codable {
    let quotes: [YahooQuote]
}

struct YahooQuote: Codable {
    let symbol: String
    let shortname: String?
    let longname: String?
    let score: Double?
    let typeDisp: String?
    let isYahooFinance: Bool?
}

// Run Debug
struct DebugApp {
    static func main() async {
        print("--- Inspecting FB Search ---")
        let query = "FB"
        let urlString = "https://query2.finance.yahoo.com/v1/finance/search?q=\(query)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonStr = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonStr)")
            }
            
            let response = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
            for (i, quote) in response.quotes.enumerated() {
                print("[\(i)] \(quote.symbol) | \(quote.shortname ?? "") | Score: \(quote.score ?? 0) | Type: \(quote.typeDisp ?? "")")
            }
        } catch {
            print("Error: \(error)")
        }
    }
}

let semaphore = DispatchSemaphore(value: 0)
Task {
    await DebugApp.main()
    semaphore.signal()
}
semaphore.wait()
