//
//  MainTabBarController.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureStyle()
        configureTabBarNavigation()
    }
    
    private func configureTabBarNavigation() {
        let quotesVC                = QuotesViewController()
        let quoteInteractor         = QuotesInteractor(apiService: ApiService.shared)
        let quoteRouter             = QuoteRouter()
        let quotePresenter          = QuotesPresenter(view: quotesVC, interactor: quoteInteractor, router: quoteRouter)
        
        quoteRouter.viewController  = quotesVC
        
        quoteInteractor.presenter   = quotePresenter
        quotesVC.presenter          = quotePresenter
        
        quotesVC.tabBarItem         = UITabBarItem(title: "Cotações", image: UIImage(systemName: "chart.bar"), tag: 0)
        
        let favoritesVC             = FavoritesViewController()
        favoritesVC.tabBarItem      = UITabBarItem(title: "Favoritos", image: UIImage(systemName: "star"), tag: 2)

        let portfolioVC             = PortfolioViewController()
        portfolioVC.tabBarItem      = UITabBarItem(title: "Carteira", image: UIImage(systemName: "briefcase"), tag: 1)

        viewControllers = [
            UINavigationController(rootViewController: quotesVC),
            UINavigationController(rootViewController: portfolioVC),
            UINavigationController(rootViewController: favoritesVC)
        ]
    }
    
    private func configureStyle() {
        let appearance = UITabBarAppearance()
        
        appearance.configureWithTransparentBackground()
        
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        tabBar.tintColor = UIColor(named: "BrandGreen")
    }
}
