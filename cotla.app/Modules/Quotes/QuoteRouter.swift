//
//  QuoeteRouter.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit

protocol QuoteRouterProtocol: AnyObject {
    func navigateToQuoteDetail(of ticker: StockEntity)
}

final class QuoteRouter: QuoteRouterProtocol {
    weak var viewController: UIViewController?
    
    func navigateToQuoteDetail(of ticker: StockEntity) {
        let detailVC         = QuoteDetailViewController(ticker: ticker)
        let detailInteractor = QuoteDetailInteractor(apiService: ApiService.shared)
        let detailPresenter  = QuoteDetailPresenter(view: detailVC, interactor: detailInteractor, symbol: ticker.symbol, assetType: ticker.assetType)

        detailInteractor.presenter = detailPresenter
        detailVC.presenter         = detailPresenter

        viewController?.navigationController?.pushViewController(detailVC, animated: true)
    }
}
