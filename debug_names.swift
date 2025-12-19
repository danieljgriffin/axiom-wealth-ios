import Foundation

// Mock Models
struct MarketMetadata {
    let symbol: String
    let name: String?
    let currency: String?
    let regularMarketPrice: Double?
}

struct InvestmentSearchResult: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let currentPrice: Double
}

// Mock Service
class MarketDataService {
    static let shared = MarketDataService()
    
    func fetchMetadata(for symbols: [String]) async -> [String: MarketMetadata] {
        var results: [String: MarketMetadata] = [:]
        for symbol in symbols {
            if let details = try? await self.fetchQuoteDetails(for: symbol) {
                print("✅ Found Quote for \(symbol): \(details.longName ?? details.shortName ?? "No Name")")
                results[symbol] = MarketMetadata(
                    symbol: symbol,
                    name: details.longName ?? details.shortName,
                    currency: details.currency,
                    regularMarketPrice: details.regularMarketPrice
                )
            } else {
                print("❌ Failed Quote for \(symbol)")
            }
        }
        return results
    }
    
    func search(query: String) async -> [InvestmentSearchResult] {
        let urlString = "https://query2.finance.yahoo.com/v1/finance/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
            return response.quotes.map { quote in
                InvestmentSearchResult(
                    symbol: quote.symbol,
                    name: quote.shortname ?? quote.longname ?? quote.symbol,
                    currentPrice: 0.0
                )
            }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    private func fetchQuoteDetails(for symbol: String) async throws -> YahooQuoteResult {
        let urlString = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Print JSON for debug
            if let jsonStr = String(data: data, encoding: .utf8) {
                // print("📄 Quote JSON for \(symbol): \(jsonStr.prefix(200))...")
            }
            
            let response = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
            if let result = response.quoteResponse.result.first {
                return result
            } else {
                throw URLError(.cannotParseResponse)
            }
        } catch {
            print("⚠️ Quote Error for \(symbol): \(error)")
            throw error
        }
    }
    
    func fetchChartData(for symbol: String) async throws -> YahooChartData {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            if let result = response.chart.result.first {
                return result
            } else {
                throw URLError(.cannotParseResponse)
            }
        } catch {
            print("⚠️ Chart Error for \(symbol): \(error)")
            throw error
        }
    }
}

// Models
struct YahooSearchResponse: Codable {
    let quotes: [YahooQuote]
}

struct YahooQuote: Codable {
    let symbol: String
    let shortname: String?
    let longname: String?
}

struct YahooQuoteResponse: Codable {
    let quoteResponse: YahooQuoteResultList
}

struct YahooQuoteResultList: Codable {
    let result: [YahooQuoteResult]
}

struct YahooQuoteResult: Codable {
    let symbol: String
    let longName: String?
    let shortName: String?
    let regularMarketPrice: Double?
    let currency: String?
}

// Chart Models
struct YahooChartResponse: Codable {
    let chart: YahooChart
}
struct YahooChart: Codable {
    let result: [YahooChartData]
}
struct YahooChartData: Codable {
    let meta: YahooChartMeta
}
struct YahooChartMeta: Codable {
    let regularMarketPrice: Double
    let currency: String?
    let longName: String?
    let shortName: String?
}

// Run Debug
struct DebugApp {
    static func main() async {
        print("--- Starting Debug ---")
        let service = MarketDataService.shared
        
        // 1. Test Fetch Metadata (Should fail for now)
        print("\n1. Testing fetchMetadata...")
        _ = await service.fetchMetadata(for: ["NVDA"])
        
        // 2. Test Chart Data (Fallback)
        print("\n2. Testing fetchChartData (Fallback)...")
        for symbol in ["NVDA", "TSLA", "FB", "RR.L"] {
            do {
                let chart = try await service.fetchChartData(for: symbol)
                print("✅ Chart for \(symbol): \(chart.meta.longName ?? chart.meta.shortName ?? "No Name")")
            } catch {
                print("❌ Chart Failed for \(symbol)")
            }
        }
    }
}

let semaphore = DispatchSemaphore(value: 0)
Task {
    await DebugApp.main()
    semaphore.signal()
}
semaphore.wait()
