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
    func search(query: String)
    func filter(by kind: AssetKind?)
    func didSelectTicker(_ ticker: StockEntity)
    func refresh()
}

protocol QuotesViewProtocol: AnyObject {
    func display(tickers: StockListResponse)
    func appendTickers(_ tickers: [StockEntity])
    func displayError(message: String)
    func endRefreshing()
}

class QuotesPresenter: QuotesPresenterProtocol, QuotesInteractorOutputProtocol {
    weak var view: QuotesViewProtocol?
    var interactor: QuotesInteractorProtocol
    
    private var currentPage           = 1
    private var hasNextPage           = true
    private var isLoadingPage         = false
    private var isRefreshing          = false
    private var hasPendingRefresh     = false
    private var currentSearch: String = ""
    private var currentKind: AssetKind?

    var router: QuoteRouter


    init(view: QuotesViewProtocol, interactor: QuotesInteractorProtocol, router: QuoteRouter) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }

    private func loadPage(isFirstPage: Bool, showsOverlay: Bool = true) {
        isLoadingPage = true
        if isFirstPage && showsOverlay { LoadingOverlay.shared.show() }
        interactor.getTickers(page: currentPage, search: currentSearch, kind: currentKind, isFirstPage: isFirstPage)
    }

    func viewDidLoad() {
        loadPage(isFirstPage: true)
    }

    func refresh() {
        // Sem isso, puxar durante o carregamento de uma página deixava o spinner girando pra sempre.
        guard !isLoadingPage else {
            hasPendingRefresh = true
            return
        }
        isRefreshing = true
        currentPage  = 1
        hasNextPage  = true
        loadPage(isFirstPage: true, showsOverlay: false)
    }

    private func finishRefreshing() {
        guard isRefreshing else { return }
        isRefreshing = false
        view?.endRefreshing()
    }

    private func runPendingRefreshIfNeeded() {
        guard hasPendingRefresh else { return }
        hasPendingRefresh = false
        refresh()
    }
    
    func loadNextPageIfNeeded(currentIndex: Int, totalCount: Int) {
        guard  totalCount > 0, currentIndex == totalCount - 1 else { return }
        guard  hasNextPage, !isLoadingPage else { return }
        
        loadPage(isFirstPage: false)
     }
    
     func onFetchSuccess(response: StockListResponse, isFirstPage: Bool) {
        isLoadingPage = false
        currentPage += 1

        if isFirstPage {
            LoadingOverlay.shared.hide()
            view?.display(tickers: response)
            finishRefreshing()
        } else {
            view?.appendTickers(response.results)
        }

        runPendingRefreshIfNeeded()
    }
    
    func search(query: String) {
        currentSearch   = query.isEmpty ? "" : query
        currentPage     = 1
        hasNextPage     = true
        loadPage(isFirstPage: true)
    }

    func filter(by kind: AssetKind?) {
        currentKind = kind
        currentPage = 1
        hasNextPage = true
        loadPage(isFirstPage: true)
    }

    func onFetchError(error: Error, isFirstPage: Bool) {
        isLoadingPage = false
        LoadingOverlay.shared.hide()
        finishRefreshing()

        // Falha ao paginar mantém o que já está na tela.
        if isFirstPage {
            switch error as? CotlaError {
            case .paidFeatureRequired, .unauthorized:
                view?.displayError(message: "Esta categoria exige um plano pago da brapi")
            default:
                view?.displayError(message: "Não foi possível carregar as cotações")
            }
        }

        runPendingRefreshIfNeeded()
    }
    
    func didSelectTicker(_ ticker: StockEntity) {
        router.navigateToQuoteDetail(of: ticker)
    }
}
