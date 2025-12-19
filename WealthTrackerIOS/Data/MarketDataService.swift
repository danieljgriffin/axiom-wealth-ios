import Foundation

class MarketDataService {
    static let shared = MarketDataService()
    
    private init() {}
    
    // MARK: - Search
    
    func search(query: String) async -> [InvestmentSearchResult] {
        guard !query.isEmpty else { return [] }
        
        let urlString = "https://query2.finance.yahoo.com/v1/finance/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
            
            return response.quotes.map { quote in
                InvestmentSearchResult(
                    symbol: quote.symbol,
                    name: quote.shortname ?? quote.longname ?? quote.symbol,
                    currentPrice: 0.0 // Search doesn't return reliable price
                )
            }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    // MARK: - Chart Data (Used for Enrichment)
    
    private func fetchChartData(for symbol: String) async throws -> YahooChartData {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        
        if let result = response.chart.result.first {
            return result
        } else {
            throw URLError(.cannotParseResponse)
        }
    }

    // MARK: - Quote Details (Better than Chart for Metadata)
    
    private func fetchQuoteDetails(for symbol: String) async throws -> YahooQuoteResult {
        let urlString = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
        
        if let result = response.quoteResponse.result.first {
            return result
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
    
    // MARK: - Price Fetching
    
    func fetchCurrentPrice(for symbol: String) async throws -> Double {
        // 1. Try Quote API first
        if let details = try? await fetchQuoteDetails(for: symbol), let price = details.regularMarketPrice, price > 0 {
            return price
        }
        
        // 2. Fallback to Chart API (needed for some funds like 0P000...)
        let chartData = try await fetchChartData(for: symbol)
        return chartData.meta.regularMarketPrice
    }
    
    func fetchCurrentPrices(for symbols: [String]) async -> [String: Double] {
        var results: [String: Double] = [:]
        
        // Fetch in parallel
        await withTaskGroup(of: (String, Double?).self) { group in
            for symbol in symbols {
                group.addTask {
                    if let price = try? await self.fetchCurrentPrice(for: symbol) {
                        return (symbol, price)
                    }
                    return (symbol, nil)
                }
            }
            
            for await (symbol, price) in group {
                if let price = price {
                    results[symbol] = price
                }
            }
        }
        
        return results
    }
    
    // MARK: - Metadata Enrichment (Trading 212 Fallback)
    
    func fetchMetadata(for symbols: [String]) async -> [String: MarketMetadata] {
        var results: [String: MarketMetadata] = [:]
        
        await withTaskGroup(of: (String, MarketMetadata?).self) { group in
            for symbol in symbols {
                group.addTask {
                    // Try Quote API
                    if let details = try? await self.fetchQuoteDetails(for: symbol) {
                        return (symbol, MarketMetadata(
                            symbol: symbol,
                            name: details.longName ?? details.shortName,
                            currency: details.currency,
                            regularMarketPrice: details.regularMarketPrice
                        ))
                    }
                    
                    // Fallback: Try Chart API (v8) - More robust for metadata
                    if let chartData = try? await self.fetchChartData(for: symbol) {
                        return (symbol, MarketMetadata(
                            symbol: symbol,
                            name: chartData.meta.longName ?? chartData.meta.shortName,
                            currency: chartData.meta.currency,
                            regularMarketPrice: chartData.meta.regularMarketPrice
                        ))
                    }
                    
                    return (symbol, nil)
                }
            }
            
            for await (symbol, metadata) in group {
                if let metadata = metadata {
                    results[symbol] = metadata
                }
            }
        }
        
        return results
    }
}

// MARK: - Models

struct InvestmentSearchResult: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let currentPrice: Double
}

struct MarketMetadata {
    let symbol: String
    let name: String?
    let currency: String?
    let regularMarketPrice: Double?
}

// Yahoo API Models
private struct YahooSearchResponse: Codable {
    let quotes: [YahooQuote]
}

private struct YahooQuote: Codable {
    let symbol: String
    let shortname: String?
    let longname: String?
}

// New Quote API Models
private struct YahooQuoteResponse: Codable {
    let quoteResponse: YahooQuoteResultList
}

private struct YahooQuoteResultList: Codable {
    let result: [YahooQuoteResult]
}

private struct YahooQuoteResult: Codable {
    let symbol: String
    let longName: String?
    let shortName: String?
    let regularMarketPrice: Double?
    let currency: String?
}

// Chart API Models
private struct YahooChartResponse: Codable {
    let chart: YahooChart
}

private struct YahooChart: Codable {
    let result: [YahooChartData]
}

private struct YahooChartData: Codable {
    let meta: YahooChartMeta
}

private struct YahooChartMeta: Codable {
    let regularMarketPrice: Double
    let currency: String?
    let longName: String?
    let shortName: String?
}
