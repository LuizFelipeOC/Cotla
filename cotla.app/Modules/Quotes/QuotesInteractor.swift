//
//  QuotesInteractor.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation



protocol QuotesInteractorProtocol: AnyObject {
    func getTickers(page: Int)
}

protocol QuotesInteractorOutputProtocol: AnyObject {
    func onFetchSuccess(tickers: StockListResponse)
    func onFetchError(error: Error)
}

class QuotesInteractor: QuotesInteractorProtocol {
    weak var presenter: QuotesInteractorOutputProtocol?

    func getTickers(page: Int) {
        ApiService.shared.getAllTickers(for: page) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let tickers):
                    self.presenter?.onFetchSuccess(tickers: tickers)
                case .failure(let error):
                    self.presenter?.onFetchError(error: error)
                }
            }
        }
    }
}
