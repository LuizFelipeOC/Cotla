//
//  FavoritesViewController.swift
//  cotla.app
//

import UIKit

class FavoritesViewController: UIViewController {

    private var favorites: [StockEntity] = []
    private let router = QuoteRouter()

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()

        router.viewController = self
        refreshQuotes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload(with: FavoritesStore.all())
    }

    private func configure() {
        title = "Favoritos"
        navigationController?.navigationBar.prefersLargeTitles = true

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear

        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance    = appearance

        view.backgroundColor = .systemBackground
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = UIColor(named: "BrandGreen")
        control.addTarget(self, action: #selector(refreshQuotes), for: .valueChanged)
        return control
    }()

    private lazy var emptyLabel: UILabel = {
        let label  = SecondayLabelView(textAligment: .center, fontSize: 16)
        // Como backgroundView, a tabela posiciona pelo frame; com Auto Layout ligado o texto saía do centro.
        label.translatesAutoresizingMaskIntoConstraints = true
        label.text = "Nenhum ativo favoritado ainda.\nToque na ⭐️ de um ativo para adicioná-lo aqui."
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()

        tableView.dataSource         = self
        tableView.delegate           = self

        tableView.register(TickerCell.self, forCellReuseIdentifier: TickerCell.reuseIdentifier)
        tableView.rowHeight          = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.separatorStyle     = .none
        tableView.backgroundColor    = .systemBackground
        tableView.refreshControl     = refreshControl

        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

    private func reload(with favorites: [StockEntity]) {
        self.favorites = favorites
        tableView.backgroundView = favorites.isEmpty ? emptyLabel : nil
        tableView.reloadData()
    }

    /// Atualiza as cotações salvas buscando cada símbolo na API.
    // ponytail: uma requisição por favorito em sequência; trocar por um endpoint em lote se a lista crescer
    @objc private func refreshQuotes() {
        Task {
            var updated: [StockEntity] = []

            for favorite in FavoritesStore.all() {
                let response = try? await ApiService.shared.getAllTickers(for: 1, search: favorite.symbol, kind: nil)
                updated.append(response?.results.first { $0.symbol == favorite.symbol } ?? favorite)
            }

            // Respeita favoritos removidos/adicionados enquanto a atualização rodava.
            let current = FavoritesStore.all()
            let merged  = current.map { stock in updated.first { $0.symbol == stock.symbol } ?? stock }

            FavoritesStore.save(merged)
            reload(with: merged)
            refreshControl.endRefreshing()
        }
    }
}

extension FavoritesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        favorites.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TickerCell.reuseIdentifier, for: indexPath) as? TickerCell else {
            return UITableViewCell()
        }

        cell.configure(with: favorites[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        router.navigateToQuoteDetail(of: favorites[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let remove = UIContextualAction(style: .destructive, title: "Remover") { [weak self] _, _, completion in
            guard let self else { return completion(false) }

            FavoritesStore.toggle(self.favorites[indexPath.row])
            self.favorites.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.backgroundView = self.favorites.isEmpty ? self.emptyLabel : nil
            completion(true)
        }
        remove.image = UIImage(systemName: "star.slash")

        return UISwipeActionsConfiguration(actions: [remove])
    }
}
