//
//  QuoteDetailPresenter.swift
//  cotla.app
//

import Foundation

protocol QuoteDetailPresenterProtocol: AnyObject {
    func viewDidLoad()
}

protocol QuoteDetailViewProtocol: AnyObject {
    func showChartLoading()
    func displayChart(prices: [HistoricalPriceEntity])
    func displayChartError(message: String)

    func showDividendsLoading()
    func displayDividends(_ dividends: [CashDividendEntity])
    func displayDividendsError(message: String)
}

class QuoteDetailPresenter: QuoteDetailPresenterProtocol, QuoteDetailInteractorOutputProtocol {
    weak var view: QuoteDetailViewProtocol?
    var interactor: QuoteDetailInteractorProtocol

    private let symbol: String
    private let isFii: Bool

    init(view: QuoteDetailViewProtocol, interactor: QuoteDetailInteractorProtocol, symbol: String, assetType: String) {
        self.view       = view
        self.interactor = interactor
        self.symbol     = symbol
        self.isFii      = assetType == "fund"
    }

    func viewDidLoad() {
        view?.showChartLoading()
        interactor.getCurrentMonthHistorical(symbol: symbol)

        view?.showDividendsLoading()
        interactor.getDividends(symbol: symbol, isFii: isFii)
    }

    func onHistoricalSuccess(prices: [HistoricalPriceEntity]) {
        guard prices.contains(where: { $0.close != nil }) else {
            view?.displayChartError(message: "Sem dados para este mês")
            return
        }

        view?.displayChart(prices: prices)
    }

    func onHistoricalError(error: Error) {
        switch error as? CotlaError {
        case .unauthorized:
            view?.displayChartError(message: "Adicione um token de acesso para ver o histórico deste ativo")
        case .tooManyRequests:
            view?.displayChartError(message: "Muitas requisições agora, tente novamente em instantes")
        default:
            view?.displayChartError(message: "Não foi possível carregar o gráfico")
        }
    }

    func onDividendsSuccess(dividends: [CashDividendEntity]) {
        view?.displayDividends(dividends)
    }

    func onDividendsError(error: Error) {
        switch error as? CotlaError {
        case .unauthorized:
            view?.displayDividendsError(message: "Adicione um token de acesso para ver os dividendos deste ativo")
        case .paidFeatureRequired:
            view?.displayDividendsError(message: "Dividendos deste ativo exigem um plano pago")
        case .tooManyRequests:
            view?.displayDividendsError(message: "Muitas requisições agora, tente novamente em instantes")
        default:
            view?.displayDividendsError(message: "Não foi possível carregar os dividendos")
        }
    }
}
