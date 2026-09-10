//
//  QuotesInteractor.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation



protocol QuotesInteractorProtocol: AnyObject {
    func getTickers(page: Int, search: String, isFirstPage: Bool)
}

protocol QuotesInteractorOutputProtocol: AnyObject {
    func onFetchSuccess(response: StockListResponse, isFirstPage: Bool)
    func onFetchError(error: Error)
}

class QuotesInteractor: QuotesInteractorProtocol {
    weak var presenter: QuotesInteractorOutputProtocol?
    
    private let apiService: ApiServiceProtocol
    
    init(apiService: ApiServiceProtocol) {
        self.apiService = apiService
    }

    func getTickers(page: Int, search: String,isFirstPage: Bool) {
        Task {
            do {
                let response = try await apiService.getAllTickers(for: page, search: search)
                
                await MainActor.run {
                    self.presenter?.onFetchSuccess(response:response, isFirstPage: isFirstPage)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.onFetchError(error: error)
                }
            }
        }
    }
}
