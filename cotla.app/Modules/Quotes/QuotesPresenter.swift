//
//  QuotesPresenter.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation

protocol QuotesPresenterProtocol: AnyObject {
    func viewDidLoad()
}

protocol QuotesViewProtocol: AnyObject {
    func display(tickers: StockListResponse)
    func displayError(message: String)
}

class QuotesPresenter: QuotesPresenterProtocol, QuotesInteractorOutputProtocol {
    weak var view: QuotesViewProtocol?
    var interactor: QuotesInteractorProtocol

    init(view: QuotesViewProtocol, interactor: QuotesInteractorProtocol) {
        self.view = view
        self.interactor = interactor
    }

    func viewDidLoad() {
        LoadingOverlay.shared.show()
        interactor.getTickers(page: 1)
    }

    func onFetchSuccess(tickers: StockListResponse) {
        LoadingOverlay.shared.hide()
        view?.display(tickers: tickers)
    }

    func onFetchError(error: Error) {
        LoadingOverlay.shared.hide()
        view?.displayError(message: "Não foi possível carregar as cotações")
    }
}
