//
//  PortfolioViewController.swift
//  cotla.app
//

import UIKit

class PortfolioViewController: UIViewController {

    private var positions: [PositionEntity] = []
    private var cryptoQuotesUnavailable     = false

    private var selectedKind: AssetKind {
        AssetKind.allCases[kindControl.selectedSegmentIndex]
    }

    private var visiblePositions: [PositionEntity] {
        positions.filter { $0.kind == selectedKind }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()

        refreshQuotes()
    }

    /// Recarrega ao voltar para a aba, já que dá para adicionar ativos a partir da lista de cotações.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()

        // Ativo recém-adicionado (aqui ou pela lista de cotações) ainda sem proventos calculados.
        if positions.contains(where: { $0.lots != nil && $0.dividendsReceived == nil && ($0.kind == .stock || $0.kind == .fii) }) {
            refreshQuotes()
        }
    }

    private func configure() {
        title = "Carteira"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPosition)),
            UIBarButtonItem(image: UIImage(systemName: "chart.line.uptrend.xyaxis"), style: .plain, target: self, action: #selector(showPerformance))
        ]
        navigationItem.rightBarButtonItems?.forEach { $0.tintColor = UIColor(named: "BrandGreen") }
        navigationItem.rightBarButtonItems?.last?.accessibilityLabel = "Desempenho e proventos"

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear

        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance    = appearance

        view.backgroundColor = .systemBackground

        summaryCard.addSubview(summaryStack)
        view.addSubview(summaryCard)
        view.addSubview(kindControl)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            summaryCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            summaryStack.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 16),
            summaryStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -16),
            summaryStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            summaryStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),

            kindControl.topAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: 16),
            kindControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            kindControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: kindControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Resumo

    private let summaryCard = CardView()

    private let captionLabel: UILabel = {
        let label  = SecondayLabelView(textAligment: .left, fontSize: 14)
        label.text      = "Patrimônio"
        label.textColor = .secondaryLabel
        return label
    }()

    private let totalLabel    = TitleLabelView(textAligment: .left, fontSize: 32)
    private let investedLabel = SecondayLabelView(textAligment: .left, fontSize: 14)
    private let resultLabel   = SecondayLabelView(textAligment: .right, fontSize: 14)
    private let dividendsLabel = SecondayLabelView(textAligment: .left, fontSize: 14)
    private let returnLabel    = SecondayLabelView(textAligment: .right, fontSize: 14)

    private lazy var summaryStack: UIStackView = {
        let firstRow   = UIStackView(arrangedSubviews: [investedLabel, resultLabel])
        let secondRow  = UIStackView(arrangedSubviews: [dividendsLabel, returnLabel])

        let footer     = UIStackView(arrangedSubviews: [firstRow, secondRow])
        footer.axis    = .vertical
        footer.spacing = 4

        let stack     = UIStackView(arrangedSubviews: [captionLabel, totalLabel, footer, allocationChart])
        stack.axis    = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(10, after: totalLabel)
        stack.setCustomSpacing(16, after: footer)

        return stack
    }()

    private let allocationChart = AllocationChartView()

    private lazy var kindControl: UISegmentedControl = {
        let control = UISegmentedControl(items: AssetKind.allCases.map(\.title))
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(kindChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    // MARK: - Lista

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = UIColor(named: "BrandGreen")
        control.addTarget(self, action: #selector(refreshQuotes), for: .valueChanged)
        return control
    }()

    private let emptyLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .center, fontSize: 16)
        // Como backgroundView, a tabela posiciona pelo frame; com Auto Layout ligado o texto saía do centro.
        label.translatesAutoresizingMaskIntoConstraints = true
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)

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

    /// Com `deletedRow`, anima a saída da linha em vez de recarregar a tabela inteira.
    private func reload(deletedRow: IndexPath? = nil) {
        positions = PortfolioStore.all()

        // Como no Investidor10: variação olha só o preço; rentabilidade soma os proventos recebidos.
        let invested   = positions.reduce(0) { $0 + $1.invested }
        let total      = positions.reduce(0) { $0 + $1.currentValue }
        let dividends  = positions.reduce(0) { $0 + ($1.dividendsReceived ?? 0) }
        let variation  = total - invested
        let variationPercent = invested > 0 ? variation / invested * 100 : 0
        let returnPercent    = invested > 0 ? (variation + dividends) / invested * 100 : 0

        totalLabel.text          = total.asCurrency
        investedLabel.text       = "Investido \(invested.asCurrency)"
        resultLabel.text         = String(format: "Variação %@%@ (%@%.2f%%)", variation >= 0 ? "+" : "-", abs(variation).asCurrency, variationPercent >= 0 ? "+" : "", variationPercent)
        resultLabel.textColor    = variation >= 0 ? .systemGreen : .systemRed
        dividendsLabel.text      = "Proventos \(dividends.asCurrency)"
        returnLabel.text         = String(format: "Rentabilidade %@%.2f%%", returnPercent >= 0 ? "+" : "", returnPercent)
        returnLabel.textColor    = returnPercent >= 0 ? .systemGreen : .systemRed

        // Categorias zeradas continuam no gráfico com valor 0 para a fatia encolher animada em vez de sumir.
        let slices = AssetKind.allCases.map { kind in
            AllocationChartView.Slice(kind: kind, value: positions.filter { $0.kind == kind }.reduce(0) { $0 + $1.currentValue })
        }

        // Só anima depois que a tela já apareceu, para não animar a primeira montagem.
        allocationChart.setSlices(slices, animated: allocationChart.window != nil && !allocationChart.isHidden)
        allocationChart.isHidden = total <= 0

        emptyLabel.text          = "Nenhum ativo em \(selectedKind.title).\nToque em + para adicionar."
        tableView.backgroundView = visiblePositions.isEmpty ? emptyLabel : nil

        if let deletedRow {
            // O reload no fim só atualiza o total do cabeçalho da seção.
            tableView.performBatchUpdates({ tableView.deleteRows(at: [deletedRow], with: .automatic) }) { _ in
                self.tableView.reloadData()
            }
        } else {
            tableView.reloadData()
        }
    }

    @objc private func kindChanged() {
        reload()
    }

    @objc private func showPerformance() {
        navigationController?.pushViewController(PerformanceViewController(), animated: true)
    }

    @objc private func addPosition() {
        let form    = AddPositionViewController(kind: selectedKind)
        form.onSave = { [weak self] kind in
            guard let self else { return }
            self.kindControl.selectedSegmentIndex = AssetKind.allCases.firstIndex(of: kind) ?? 0
            self.reload()
            self.refreshQuotes()
        }

        present(UINavigationController(rootViewController: form), animated: true)
    }

    /// Atualiza as cotações: ações e FIIs um a um pelo /tickers, cripto numa única chamada.
    // ponytail: uma requisição por ação/FII em sequência; trocar por um endpoint em lote se a carteira crescer
    @objc private func refreshQuotes() {
        Task {
            var quotes: [String: (price: Double, logo: String?)] = [:]
            let current = PortfolioStore.all()

            for position in current where position.kind == .treasury {
                let bond = try? await ApiService.shared.getTreasury(page: 1, search: position.symbol).results.first { $0.symbol == position.symbol }
                if let price = bond?.sellPrice {
                    quotes[Self.key(position.kind, position.symbol)] = (price, nil)
                }
            }

            for position in current where position.kind == .stock || position.kind == .fii {
                if let stock = try? await PortfolioQuotes.stock(symbol: position.symbol) {
                    quotes[Self.key(position.kind, position.symbol)] = (stock.quote.lastPrice, stock.logoUrl)
                }
            }

            let coins = current.filter { $0.kind == .crypto }.map(\.symbol)

            if !coins.isEmpty {
                do {
                    for coin in try await ApiService.shared.getCrypto(coins: coins).coins {
                        quotes[Self.key(.crypto, coin.coin)] = (coin.regularMarketPrice, coin.coinImageUrl)
                    }
                    cryptoQuotesUnavailable = false
                } catch CotlaError.paidFeatureRequired {
                    cryptoQuotesUnavailable = true
                } catch {}
            }

            // Proventos: FII tem endpoint próprio na brapi. Falha num ativo só mantém o valor anterior.
            var dividendsByKey: [String: [CashDividendEntity]] = [:]

            for position in current where (position.kind == .stock || position.kind == .fii) && position.lots != nil {
                let dividends = position.kind == .fii
                    ? try? await ApiService.shared.getFiiDividends(symbol: position.symbol).dividends
                    : try? await ApiService.shared.getDividends(symbol: position.symbol).results.first?.data.cashDividends
                dividendsByKey[Self.key(position.kind, position.symbol)] = dividends
            }

            let today = Self.day.format(Date())

            // Relê do disco para não desfazer algo adicionado/removido enquanto a atualização rodava.
            PortfolioStore.save(PortfolioStore.all().map { position in
                let key     = Self.key(position.kind, position.symbol)
                var updated = position

                if let quote = quotes[key] {
                    updated.currentPrice = quote.price
                    updated.logoUrl      = quote.logo ?? position.logoUrl
                }

                if let dividends = dividendsByKey[key] {
                    updated.dividendsReceived = position.dividendsReceived(from: dividends, today: today)
                }

                return updated
            })

            reload()
            refreshControl.endRefreshing()
        }
    }

    private static let day = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()

    private static func key(_ kind: AssetKind, _ symbol: String) -> String {
        "\(kind.rawValue):\(symbol)"
    }
}

extension PortfolioViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visiblePositions.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let visible = visiblePositions
        guard !visible.isEmpty else { return nil }

        return "\(selectedKind.title) · \(visible.reduce(0) { $0 + $1.currentValue }.asCurrency)"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard selectedKind == .crypto, cryptoQuotesUnavailable, !visiblePositions.isEmpty else { return nil }

        return "A cotação de cripto exige um plano pago da brapi. Os valores usam o preço médio informado."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TickerCell.reuseIdentifier, for: indexPath) as? TickerCell else {
            return UITableViewCell()
        }

        let position = visiblePositions[indexPath.row]
        let quantity = position.quantity.formatted(.number.precision(.fractionLength(0...4)).locale(Locale(identifier: "pt_BR")))

        cell.configure(
            symbol: position.name ?? position.symbol,
            subtitle: "\(quantity) × PM \(position.averagePrice.asCurrency)",
            value: position.currentValue,
            changePercent: position.resultPercent,
            logoUrl: position.logoUrl
        )

        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let position = visiblePositions[indexPath.row]

        let remove = UIContextualAction(style: .destructive, title: "Remover") { [weak self] _, _, completion in
            PortfolioStore.remove(position)
            self?.reload(deletedRow: indexPath)
            completion(true)
        }
        remove.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [remove])
    }
}

enum PortfolioQuotes {
    /// Busca exata pelo símbolo no /tickers (a busca da brapi também devolve símbolos parecidos).
    static func stock(symbol: String) async throws -> StockEntity? {
        try await ApiService.shared.getAllTickers(for: 1, search: symbol, kind: nil).results.first { $0.symbol == symbol }
    }
}
