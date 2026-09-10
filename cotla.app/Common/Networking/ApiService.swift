//
//  ApiService.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation


protocol ApiServiceProtocol {
    func getAllTickers(for page: Int, search: String) async throws -> StockListResponse
}

class ApiService: ApiServiceProtocol {
    static let shared = ApiService()
    
    let baseUrl: String = "https://brapi.dev/api/v2"
    let limit: Int = 50
    
    
    func getAllTickers(for page: Int, search: String) async throws -> StockListResponse {
        guard let url = URL(string: "\(baseUrl)/tickers?page=\(page)&limit=\(limit)&search=\(search)") else {
            throw CotlaError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CotlaError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(StockListResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }
    
}
