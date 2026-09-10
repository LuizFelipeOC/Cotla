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
        let quotePresenter          = QuotesPresenter(view: quotesVC, interactor: quoteInteractor)
        
        quoteInteractor.presenter   = quotePresenter
        quotesVC.presenter          = quotePresenter
        
        quotesVC.tabBarItem         = UITabBarItem(title: "Cotações", image: UIImage(systemName: "chart.bar"), tag: 0)
        
        viewControllers = [
            UINavigationController(rootViewController: quotesVC)
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
