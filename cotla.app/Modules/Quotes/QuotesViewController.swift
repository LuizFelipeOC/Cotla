//
//  QuoetesViewController.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit

class QuotesViewController: UIViewController, QuotesViewProtocol {
    
    var presenter: QuotesPresenterProtocol!
    
    private var tickers: [StockEntity] = []
    private var isSearching: Bool      = false
    private var searchTask: Task<Void, Never>?
    
    private let tableView        = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        
        presenter.viewDidLoad()
    }

    private func configure() {
        view.backgroundColor = .systemBackground
        configureHeader()
        configureSearchBar()
        configureTableView()
    }

    private func configureHeader() {
        title = "Cotações"
        navigationController?.navigationBar.prefersLargeTitles          = true
        navigationItem.largeTitleDisplayMode                            = .automatic
        navigationController?.hidesBarsOnSwipe                          = false
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor                                      = .systemBackground
        appearance.shadowColor                                          = .clear
        appearance.titleTextAttributes                                  = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes                             = [.foregroundColor: UIColor.label]
        
        navigationController?.navigationBar.standardAppearance          = appearance
        navigationController?.navigationBar.scrollEdgeAppearance        = appearance
        navigationController?.navigationBar.compactAppearance           = appearance
    }
    
    private func configureSearchBar() {
        searchController.searchResultsUpdater                 = self
        
        searchController.obscuresBackgroundDuringPresentation = false
                    
        searchController.searchBar.placeholder                = "Buscar ativo..."
        
        navigationItem.hidesSearchBarWhenScrolling            = true
        definesPresentationContext                            = true
        navigationItem.searchController = searchController
    }
    
    private func configureTableView() {
        tableView.dataSource                                 = self
        tableView.register(TickerCell.self, forCellReuseIdentifier: TickerCell.reuseIdentifier)
        tableView.rowHeight                                 = UITableView.automaticDimension
        tableView.estimatedRowHeight                        = 64
        tableView.separatorStyle                            = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate                                  = self
        
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func display(tickers: StockListResponse) {
        self.tickers = tickers.results
        tableView.reloadData()
    }
    
    func appendTickers(_ newTickers: [StockEntity]) {
        let startIndex  = tickers.count
        
        tickers.append(contentsOf: newTickers)

        let indexPaths  = (startIndex..<tickers.count).map { IndexPath(row: $0, section: 0) }
        
        tableView.insertRows(at: indexPaths, with: .none)
    }

    func displayError(message: String) {
        print(message)
    }
}


extension QuotesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tickers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TickerCell.reuseIdentifier, for: indexPath) as? TickerCell else {
            return UITableViewCell()
        }
        cell.configure(with: tickers[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath){
        guard !isSearching else {return }
        
        presenter.loadNextPageIfNeeded(currentIndex: indexPath.row, totalCount: tickers.count)
    }
}

extension QuotesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            presenter.search(query: query)
        }
    }
}
