//
//  QuotesInteractor.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation

protocol QuotesInteractorProtocol: AnyObject {
    func getTickers(page: Int, search: String, kind: AssetKind?, isFirstPage: Bool)
}

protocol QuotesInteractorOutputProtocol: AnyObject {
    func onFetchSuccess(response: StockListResponse, isFirstPage: Bool)
    func onFetchError(error: Error, isFirstPage: Bool)
}

class QuotesInteractor: QuotesInteractorProtocol {
    weak var presenter: QuotesInteractorOutputProtocol?
    
    private let apiService: ApiServiceProtocol
    private let cryptoPageSize = 50

    /// Trocar de filtro/busca cancela a requisição anterior, senão uma resposta atrasada sobrescreve a lista nova.
    private var currentTask: Task<Void, Never>?
    
    init(apiService: ApiServiceProtocol) {
        self.apiService = apiService
    }

    func getTickers(page: Int, search: String, kind: AssetKind?, isFirstPage: Bool) {
        currentTask?.cancel()
        currentTask = Task {
            do {
                let response: StockListResponse

                switch kind {
                case .crypto:   response = try await getCryptoPage(page: page, search: search)
                case .treasury: response = try await getTreasuryPage(page: page, search: search)
                default:        response = try await apiService.getAllTickers(for: page, search: search, kind: kind)
                }
                
                guard !Task.isCancelled else { return }
                self.presenter?.onFetchSuccess(response: response, isFirstPage: isFirstPage)
            } catch {
                guard !Task.isCancelled else { return }
                self.presenter?.onFetchError(error: error, isFirstPage: isFirstPage)
            }
        }
    }

    /// Códigos que a brapi libera no plano gratuito; a lista completa exige o Pro.
    private let freeTreasurySymbols = [
        "tesouro-selic-01032031",
        "tesouro-prefixado-com-juros-semestrais-01012037",
        "tesouro-ipca-com-juros-semestrais-15082060"
    ]

    private func getTreasuryPage(page: Int, search: String) async throws -> StockListResponse {
        do {
            let treasury = try await apiService.getTreasury(page: page, search: search)
            return StockListResponse(results: treasury.results.map(StockEntity.init(treasury:)))
        } catch CotlaError.paidFeatureRequired where page == 1 {
            // Sem o Pro, mostra ao menos os títulos de amostra que batem com a busca.
            let symbols = freeTreasurySymbols.filter { search.isEmpty || $0.contains(search.lowercased()) }
            guard !symbols.isEmpty else { throw CotlaError.paidFeatureRequired }

            var results: [StockEntity] = []
            for symbol in symbols {
                results += try await apiService.getTreasury(page: 1, search: symbol).results.map(StockEntity.init(treasury:))
            }
            return StockListResponse(results: results)
        }
    }

    /// A brapi não pagina cripto: pega a lista de códigos e cota só a fatia da página.
    private func getCryptoPage(page: Int, search: String) async throws -> StockListResponse {
        let coins     = try await apiService.getAvailableCrypto(search: search).coins
        let pageCoins = Array(coins.dropFirst((page - 1) * cryptoPageSize).prefix(cryptoPageSize))

        guard !pageCoins.isEmpty else { return StockListResponse(results: []) }

        let quotes = try await apiService.getCrypto(coins: pageCoins).coins
        return StockListResponse(results: quotes.map(StockEntity.init(crypto:)))
    }
}
