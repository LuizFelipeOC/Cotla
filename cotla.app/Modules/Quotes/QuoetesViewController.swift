//
//  QuoetesViewController.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit

class QuoetesViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    private func configure() {
        view.backgroundColor = .systemBackground
        
        configureHeader()
    }
    
    private func configureHeader() {
        title = "Cotações"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
}
