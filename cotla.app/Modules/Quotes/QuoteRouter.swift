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
        let detailVC = QuoteDetailViewController(ticker: ticker)
        viewController?.navigationController?.pushViewController(detailVC, animated: true)
    }
}
