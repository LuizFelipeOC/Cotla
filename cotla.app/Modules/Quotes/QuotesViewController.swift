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
    
    private let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        
        presenter.viewDidLoad()
    }
    
    private func configure() {
        configureHeader()
        configureSearchBar()
        
        view.backgroundColor = .systemBackground
        
        chipsScrollView.addSubview(chipsStack)
        view.addSubview(chipsScrollView)
        view.addSubview(tickersTableView)
        setContentScrollView(tickersTableView)
        
        setupLayoutConstrains()
    }
    
    private func configureHeader() {
        title = "Ativos"
        navigationController?.navigationBar.prefersLargeTitles          = true
        navigationItem.largeTitleDisplayMode                            = .automatic
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithTransparentBackground()
        
        appearance.shadowColor                                          = .clear
        
        
        navigationController?.navigationBar.standardAppearance          = appearance
        navigationController?.navigationBar.scrollEdgeAppearance        = appearance
        navigationController?.navigationBar.compactAppearance           = appearance
    }
    
    private func configureSearchBar() {
        searchController.searchResultsUpdater                       = self
        
        searchController.obscuresBackgroundDuringPresentation       = false
        
        searchController.searchBar.placeholder                      = "Buscar ativo..."
        searchController.searchBar.searchBarStyle                   = .minimal
        
        navigationItem.preferredSearchBarPlacement                  = .stacked
        
        navigationItem.hidesSearchBarWhenScrolling            = false
        definesPresentationContext                            = true
        navigationItem.searchController = searchController
    }
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = UIColor(named: "BrandGreen")
        control.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return control
    }()

    private lazy var tickersTableView: UITableView = {
        let tableView = UITableView()

        tableView.dataSource                                = self
        tableView.delegate                                  = self

        tableView.register(TickerCell.self, forCellReuseIdentifier: TickerCell.reuseIdentifier)
        tableView.rowHeight                                 = UITableView.automaticDimension
        tableView.estimatedRowHeight                        = 64
        tableView.separatorStyle                            = .none
        tableView.backgroundColor                           = .systemBackground
        tableView.refreshControl                            = refreshControl

        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

    // MARK: - Filtro

    private var selectedKind: AssetKind?

    /// Chips na ordem de `[nil] + AssetKind.allCases`; nil é "Todos".
    private lazy var chipButtons: [UIButton] = ([nil] + AssetKind.allCases).map { kind in
        let button = UIButton(configuration: .gray())
        button.configuration?.title       = kind?.title ?? "Todos"
        button.configuration?.cornerStyle = .capsule
        button.addAction(UIAction { [weak self] _ in self?.select(kind) }, for: .touchUpInside)
        return button
    }

    private let chipsScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var chipsStack: UIStackView = {
        let stack     = UIStackView(arrangedSubviews: chipButtons)
        stack.axis    = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        updateChips()
        return stack
    }()

    private func select(_ kind: AssetKind?) {
        guard kind != selectedKind else { return }

        selectedKind = kind
        updateChips()
        presenter.filter(by: kind)
    }

    private func updateChips() {
        let kinds: [AssetKind?] = [nil] + AssetKind.allCases

        for (button, kind) in zip(chipButtons, kinds) {
            let isSelected = kind == selectedKind
            let title      = button.configuration?.title

            button.configuration                          = isSelected ? .filled() : .gray()
            button.configuration?.title                   = title
            button.configuration?.cornerStyle             = .capsule
            button.configuration?.baseBackgroundColor     = isSelected ? UIColor(named: "BrandGreen") : nil
            button.configuration?.baseForegroundColor     = isSelected ? .white : .label
        }
    }

    private let emptyLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .center, fontSize: 16)
        // Como backgroundView, a tabela posiciona pelo frame; com Auto Layout ligado o texto saía do centro.
        label.translatesAutoresizingMaskIntoConstraints = true
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    @objc private func handleRefresh() {
        presenter.refresh()
    }
    
    private func setupLayoutConstrains() {
        NSLayoutConstraint.activate([
            chipsScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            chipsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chipsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chipsScrollView.heightAnchor.constraint(equalTo: chipsStack.heightAnchor),

            chipsStack.topAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.topAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.bottomAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScrollView.contentLayoutGuide.trailingAnchor, constant: -16),

            tickersTableView.topAnchor.constraint(equalTo: chipsScrollView.bottomAnchor, constant: 8),
            tickersTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tickersTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tickersTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func display(tickers: StockListResponse) {
        self.tickers = tickers.results

        emptyLabel.text                  = "Nenhum ativo encontrado"
        tickersTableView.backgroundView  = self.tickers.isEmpty ? emptyLabel : nil
        tickersTableView.reloadData()
    }
    
    func appendTickers(_ newTickers: [StockEntity]) {
        let startIndex  = tickers.count
        
        tickers.append(contentsOf: newTickers)
        
        let indexPaths  = (startIndex..<tickers.count).map { IndexPath(row: $0, section: 0) }
        
        tickersTableView.insertRows(at: indexPaths, with: .none)
    }
    
    func displayError(message: String) {
        tickers = []

        emptyLabel.text                  = message
        tickersTableView.backgroundView  = emptyLabel
        tickersTableView.reloadData()
    }

    func endRefreshing() {
        refreshControl.endRefreshing()
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Tesouro não tem gráfico nem dividendos na brapi: o toque vai direto para a carteira.
        if tickers[indexPath.row].isTreasury {
            presentAddToPortfolio(tickers[indexPath.row])
        } else {
            presenter.didSelectTicker(tickers[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let ticker = tickers[indexPath.row]

        let add = UIContextualAction(style: .normal, title: "Carteira") { [weak self] _, _, completion in
            self?.presentAddToPortfolio(ticker)
            completion(true)
        }
        add.image           = UIImage(systemName: "briefcase")
        add.backgroundColor = UIColor(named: "BrandGreen")

        return UISwipeActionsConfiguration(actions: [add])
    }
}

extension QuotesViewController {
    func presentAddToPortfolio(_ ticker: StockEntity) {
        let form = AddPositionViewController(kind: ticker.portfolioKind, symbol: ticker.symbol, displayName: ticker.displaySymbol)
        present(UINavigationController(rootViewController: form), animated: true)
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
