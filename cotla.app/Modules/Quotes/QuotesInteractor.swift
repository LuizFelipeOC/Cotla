//
//  QuotesInteractor.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation



protocol QuotesInteractorProtocol: AnyObject {
    func getTickers(page: Int, isFirstPage: Bool)
}

protocol QuotesInteractorOutputProtocol: AnyObject {
    func onFetchSuccess(response: StockListResponse, isFirstPage: Bool)
    func onFetchError(error: Error)
}

class QuotesInteractor: QuotesInteractorProtocol {
    weak var presenter: QuotesInteractorOutputProtocol?

    func getTickers(page: Int, isFirstPage: Bool) {
        ApiService.shared.getAllTickers(for: page, isFirstPage: isFirstPage) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let tickers):
                    self.presenter?.onFetchSuccess(response: tickers, isFirstPage: isFirstPage)
                case .failure(let error):
                    self.presenter?.onFetchError(error: error)
                }
            }
        }
    }
}
