import Foundation

let isin = "GB00BMN91T34"
let symbol = "0P000147T9.L" // The code Yahoo returns for this ISIN

// 1. Search API
print("--- SEARCH API (\(isin)) ---")
let searchUrl = URL(string: "https://query2.finance.yahoo.com/v1/finance/search?q=\(isin)")!
if let data = try? Data(contentsOf: searchUrl), let str = String(data: data, encoding: .utf8) {
    print(str)
}

// 2. Quote API
print("\n--- QUOTE API (\(symbol)) ---")
let quoteUrl = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)")!
if let data = try? Data(contentsOf: quoteUrl), let str = String(data: data, encoding: .utf8) {
    print(str)
}

// 3. Chart API (Alternative)
print("\n--- CHART API (\(symbol)) ---")
let chartUrl = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
if let data = try? Data(contentsOf: chartUrl), let str = String(data: data, encoding: .utf8) {
    print(str)
}
