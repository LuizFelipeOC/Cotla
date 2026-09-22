//
//  ApiService.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation


protocol ApiServiceProtocol {
    func getAllTickers(for page: Int, search: String) async throws -> StockListResponse
    func getHistorical(symbol: String, range: String, interval: String) async throws -> HistoricalResponse
    func getDividends(symbol: String) async throws -> DividendsResponse
    func getFiiDividends(symbol: String) async throws -> FiiDividendsResponse
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

    func getHistorical(symbol: String, range: String, interval: String) async throws -> HistoricalResponse {
        var components = URLComponents(string: "\(baseUrl)/stocks/historical")
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: symbol),
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "sortOrder", value: "asc")
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(HistoricalResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    func getDividends(symbol: String) async throws -> DividendsResponse {
        var components = URLComponents(string: "\(baseUrl)/stocks/dividends")
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: symbol)
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(DividendsResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    func getFiiDividends(symbol: String) async throws -> FiiDividendsResponse {
        var components = URLComponents(string: "\(baseUrl)/fii/dividends")
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: symbol)
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(FiiDividendsResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    // MARK: - Requisições autenticadas

    /// O plano gratuito da brapi tem limite de requisições por minuto; como a tela de
    /// detalhe dispara histórico e dividendos em paralelo, é fácil esbarrar nele.
    /// Por ser uma falha transitória, vale uma retentativa antes de reportar erro.
    private func authorizedData(from url: URL, retriesLeft: Int = 1) async throws -> Data {
        var request = URLRequest(url: url)

        if !AppConfig.brapiToken.isEmpty {
            request.setValue("Bearer \(AppConfig.brapiToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CotlaError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            throw CotlaError.unauthorized
        case 403:
            throw CotlaError.paidFeatureRequired
        case 429 where retriesLeft > 0:
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await authorizedData(from: url, retriesLeft: retriesLeft - 1)
        case 429:
            throw CotlaError.tooManyRequests
        default:
            throw CotlaError.invalidResponse
        }
    }
}
