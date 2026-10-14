//
//  ApiService.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation


protocol ApiServiceProtocol {
    func getAllTickers(for page: Int, search: String, kind: AssetKind?) async throws -> StockListResponse
    func getAvailableCrypto(search: String) async throws -> CryptoAvailableResponse
    func getTreasury(page: Int, search: String) async throws -> TreasuryListResponse
    func getCdi(startDate: String, endDate: String) async throws -> [CdiDayEntity]
    func getTreasuryHistory(symbol: String, startDate: String, endDate: String) async throws -> TreasuryHistoryResponse
    func getHistorical(symbol: String, range: String, interval: String) async throws -> HistoricalResponse
    func getHistorical(symbol: String, startDate: String, endDate: String) async throws -> HistoricalResponse
    func getDividends(symbol: String) async throws -> DividendsResponse
    func getFiiDividends(symbol: String) async throws -> FiiDividendsResponse
    func getCrypto(coins: [String]) async throws -> CryptoResponse
}

class ApiService: ApiServiceProtocol {
    static let shared = ApiService()

    let baseUrl: String = "https://brapi.dev/api/v2"
    let limit: Int = 50


    /// `kind` nil traz tudo. FII filtra por `subType` porque `type=fund` também traz ETFs e outros fundos.
    func getAllTickers(for page: Int, search: String, kind: AssetKind?) async throws -> StockListResponse {
        var components = URLComponents(string: "\(baseUrl)/tickers")
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "search", value: search)
        ]

        switch kind {
        case .stock:  components?.queryItems?.append(URLQueryItem(name: "type", value: "stock"))
        case .fii:    components?.queryItems?.append(URLQueryItem(name: "subType", value: "fii"))
        case .crypto, .treasury, nil: break
        }

        guard let url = components?.url else {
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

    /// Janela por data (YYYY-MM-DD), diária. O `close` é o preço negociado no dia, sem ajuste por proventos.
    func getHistorical(symbol: String, startDate: String, endDate: String) async throws -> HistoricalResponse {
        var components = URLComponents(string: "\(baseUrl)/stocks/historical")
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: symbol),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate),
            URLQueryItem(name: "interval", value: "1d")
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

    /// Exige plano pago da brapi (Startup); no gratuito lança `.paidFeatureRequired`.
    func getCrypto(coins: [String]) async throws -> CryptoResponse {
        var components = URLComponents(string: "\(baseUrl)/crypto")
        components?.queryItems = [
            URLQueryItem(name: "coin", value: coins.joined(separator: ",")),
            URLQueryItem(name: "currency", value: "BRL")
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(CryptoResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    /// Lista os códigos de cripto suportados. Também exige plano pago.
    func getAvailableCrypto(search: String) async throws -> CryptoAvailableResponse {
        var components = URLComponents(string: "\(baseUrl)/crypto/available")
        components?.queryItems = [URLQueryItem(name: "search", value: search)]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(CryptoAvailableResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    /// Lista completa exige plano Pro; no gratuito só alguns códigos de amostra respondem.
    func getTreasury(page: Int, search: String) async throws -> TreasuryListResponse {
        var components = URLComponents(string: "\(baseUrl)/treasury/list")
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "search", value: search)
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(TreasuryListResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    /// Preços diários do título; datas em YYYY-MM-DD. Mesmo plano do /treasury/list.
    func getTreasuryHistory(symbol: String, startDate: String, endDate: String) async throws -> TreasuryHistoryResponse {
        var components = URLComponents(string: "\(baseUrl)/treasury/indicators/history")
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: symbol),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate)
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        let data = try await authorizedData(from: url)

        do {
            return try JSONDecoder().decode(TreasuryHistoryResponse.self, from: data)
        } catch {
            throw CotlaError.decodingFailed
        }
    }

    /// CDI diário direto do Banco Central (SGS série 12): na brapi a série exige plano pago.
    /// Datas em DD/MM/YYYY. O firewall do BCB às vezes devolve uma página HTML no lugar do JSON,
    /// então tenta de novo antes de desistir.
    func getCdi(startDate: String, endDate: String) async throws -> [CdiDayEntity] {
        var components = URLComponents(string: "https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados")
        components?.queryItems = [
            URLQueryItem(name: "formato", value: "json"),
            URLQueryItem(name: "dataInicial", value: startDate),
            URLQueryItem(name: "dataFinal", value: endDate)
        ]

        guard let url = components?.url else {
            throw CotlaError.invalidURL
        }

        for attempt in 1...3 {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let days = try? JSONDecoder().decode([CdiDayEntity].self, from: data) {
                return days
            }
            if attempt < 3 { try await Task.sleep(nanoseconds: 700_000_000) }
        }

        throw CotlaError.invalidResponse
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
