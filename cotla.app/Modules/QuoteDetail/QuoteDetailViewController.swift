//
//  QuoteDetailViewController.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit


class QuoteDetailViewController: UIViewController {
    
    let ticker: StockEntity!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        configure()
        configureCardStock()
    }
    
    init(ticker: StockEntity) {
        self.ticker = ticker
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func configure() {
        title = ticker.symbol
        
        view.addSubview(cardStock)
    }
    
    private func configureCardStock() {
        cardStock.backgroundColor  = .red
    }
    
     private lazy var cardStock: UIView = {
         let card = CardView(frame: .zero)
         
        return card
     }()
}
