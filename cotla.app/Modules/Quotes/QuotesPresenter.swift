//
//  QuotesPresenter.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation

protocol QuotesPresenterProtocol: AnyObject {
    func viewDidLoad()
    func loadNextPageIfNeeded(currentIndex: Int, totalCount: Int)
}

protocol QuotesViewProtocol: AnyObject {
    func display(tickers: StockListResponse)
    func appendTickers(_ tickers: [StockEntity])
    func displayError(message: String)
}

class QuotesPresenter: QuotesPresenterProtocol, QuotesInteractorOutputProtocol {
    weak var view: QuotesViewProtocol?
    var interactor: QuotesInteractorProtocol
    
    private var currentPage = 1
    private var hasNextPage   = true
    private var isLoadingPage = false


    init(view: QuotesViewProtocol, interactor: QuotesInteractorProtocol) {
        self.view = view
        self.interactor = interactor
    }
    
    private func loadPage(isFirstPage: Bool) {
        isLoadingPage = true
        if isFirstPage { LoadingOverlay.shared.show() }
        interactor.getTickers(page: currentPage, isFirstPage: isFirstPage)
    }

    func viewDidLoad() {
        loadPage(isFirstPage: true)
    }
    
    func loadNextPageIfNeeded(currentIndex: Int, totalCount: Int) {
         let thresholdReached = currentIndex >= totalCount - 5
         guard thresholdReached, hasNextPage, !isLoadingPage else { return }
         loadPage(isFirstPage: false)
     }
    
     func onFetchSuccess(response: StockListResponse, isFirstPage: Bool) {
        isLoadingPage = false
        currentPage += 1

        if isFirstPage {
            LoadingOverlay.shared.hide()
            view?.display(tickers: response)
        } else {
            view?.appendTickers(response.results)
        }
    }

    func onFetchError(error: Error) {
        LoadingOverlay.shared.hide()
        view?.displayError(message: "Não foi possível carregar as cotações")
    }
}
