//
//  PortfolioViewController.swift
//  cotla.app
//

import UIKit

class PortfolioViewController: UIViewController {

    private var positions: [PositionEntity] = []
    private var cryptoQuotesUnavailable     = false
    private var dividendsAttempted: Set<String> = []

    private var selectedKind: AssetKind {
        AssetKind.allCases[kindControl.selectedSegmentIndex]
    }

    private var visiblePositions: [PositionEntity] {
        positions.filter { $0.kind == selectedKind && !$0.isClosed }
    }

    /// Vendidas por completo: ficam numa seção à parte para o histórico e o lucro realizado.
    private var closedPositions: [PositionEntity] {
        positions.filter { $0.kind == selectedKind && $0.isClosed }
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
        // Só uma tentativa por ativo na sessão: no plano gratuito a brapi bloqueia proventos de vários
        // ativos, e eles ficariam sem cálculo para sempre, refazendo as requisições a cada visita.
        if positions.contains(where: { $0.lots != nil && $0.dividendsReceived == nil && $0.kind.isListedOnB3
                                       && !dividendsAttempted.contains(Self.key($0.kind, $0.symbol)) }) {
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
    private let realizedLabel  = SecondayLabelView(textAligment: .left, fontSize: 14)

    private lazy var summaryStack: UIStackView = {
        let firstRow   = UIStackView(arrangedSubviews: [investedLabel, resultLabel])
        let secondRow  = UIStackView(arrangedSubviews: [dividendsLabel, returnLabel])

        let footer     = UIStackView(arrangedSubviews: [firstRow, secondRow, realizedLabel])
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
        control.apportionsSegmentWidthsByContent = true
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
        // As duas olham o que está em carteira; o que já foi vendido aparece no lucro realizado.
        let invested   = positions.reduce(0) { $0 + $1.invested }
        let total      = positions.reduce(0) { $0 + $1.currentValue }
        let dividends  = positions.reduce(0) { $0 + ($1.dividendsReceived ?? 0) }
        let openDividends = positions.filter { !$0.isClosed }.reduce(0) { $0 + ($1.dividendsReceived ?? 0) }
        let realized   = positions.reduce(0) { $0 + $1.realizedProfit }
        let variation  = total - invested
        let variationPercent = invested > 0 ? variation / invested * 100 : 0
        let returnPercent    = invested > 0 ? (variation + openDividends) / invested * 100 : 0

        realizedLabel.isHidden  = !positions.contains { $0.sales?.isEmpty == false }
        realizedLabel.text      = "Lucro realizado em vendas \(realized >= 0 ? "+" : "-")\(abs(realized).asCurrency)"
        realizedLabel.textColor = realized >= 0 ? .systemGreen : .systemRed

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
        tableView.backgroundView = visiblePositions.isEmpty && closedPositions.isEmpty ? emptyLabel : nil

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

            for position in current where position.kind.isListedOnB3 && !position.isClosed {
                if let stock = try? await PortfolioQuotes.stock(symbol: position.symbol) {
                    quotes[Self.key(position.kind, position.symbol)] = (stock.quote.lastPrice, stock.logoUrl)
                }
            }

            let coins = current.filter { $0.kind == .crypto && !$0.isClosed }.map(\.symbol)

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

            for position in current where position.kind.isListedOnB3 && position.lots != nil {
                let dividends = position.kind == .fii
                    ? try? await ApiService.shared.getFiiDividends(symbol: position.symbol).dividends
                    : try? await ApiService.shared.getDividends(symbol: position.symbol).results.first?.data.cashDividends
                dividendsByKey[Self.key(position.kind, position.symbol)] = dividends
                dividendsAttempted.insert(Self.key(position.kind, position.symbol))
            }

            let today = Self.day.format(Date())

            // Renda fixa: rende com o CDI do BCB desde a aplicação e vale o líquido de um resgate hoje.
            // Falha no BCB mantém o último valor calculado.
            var fixedIncomeByKey: [String: FixedIncome] = [:]
            let fixedIncomes = current.filter { $0.fixedIncome != nil }

            if let start = fixedIncomes.compactMap({ $0.lots?.first?.date }).min(),
               let days = try? await ApiService.shared.getCdi(startDate: Self.brazilianDate(start), endDate: Self.brazilianDate(today)) {
                for position in fixedIncomes {
                    guard var fixedIncome = position.fixedIncome, let date = position.lots?.first?.date else { continue }

                    let now = fixedIncome.redemption(invested: position.invested, appliedOn: date, on: today, cdi: days)
                    fixedIncome.breakdown         = now
                    fixedIncome.maturityBreakdown = fixedIncome.projectedAtMaturity(invested: position.invested, appliedOn: date, from: today,
                                                                                    gross: now.gross, cdiDailyRate: days.last?.dailyRate ?? 0)
                    fixedIncomeByKey[Self.key(position.kind, position.symbol)] = fixedIncome
                }
            }

            // Relê do disco para não desfazer algo adicionado/removido enquanto a atualização rodava.
            PortfolioStore.save(PortfolioStore.all().map { position in
                let key     = Self.key(position.kind, position.symbol)
                var updated = position

                if let quote = quotes[key] {
                    updated.currentPrice = quote.price
                    updated.logoUrl      = quote.logo ?? position.logoUrl
                }

                if let fixedIncome = fixedIncomeByKey[key] {
                    updated.fixedIncome  = fixedIncome
                    updated.currentPrice = fixedIncome.breakdown?.net
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

    /// "2026-12-21" → "21/12/2026", para exibir e para a API do BCB.
    private static func brazilianDate(_ iso: String) -> String {
        iso.split(separator: "-").reversed().joined(separator: "/")
    }

    private static func key(_ kind: AssetKind, _ symbol: String) -> String {
        "\(kind.rawValue):\(symbol)"
    }
}

extension PortfolioViewController: UITableViewDataSource, UITableViewDelegate {
    /// Seção 0: em carteira. Seção 1: encerradas.
    private func position(at indexPath: IndexPath) -> PositionEntity {
        indexPath.section == 0 ? visiblePositions[indexPath.row] : closedPositions[indexPath.row]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        closedPositions.isEmpty ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? visiblePositions.count : closedPositions.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            let realized = closedPositions.reduce(0) { $0 + $1.realizedProfit }
            return "Encerradas · lucro realizado \(realized >= 0 ? "+" : "-")\(abs(realized).asCurrency)"
        }

        let visible = visiblePositions
        guard !visible.isEmpty else { return nil }

        return "\(selectedKind.title) · \(visible.reduce(0) { $0 + $1.currentValue }.asCurrency)"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0, !visiblePositions.isEmpty else { return nil }

        if selectedKind == .fixedIncome {
            return "Valor líquido de um resgate hoje, na curva: rende por dia útil (base 252) com o CDI do Banco Central, "
                + "com IOF regressivo até o 29º dia e IR regressivo de 22,5% a 15% sobre o rendimento. "
                + "LCI, LCA e debênture incentivada são isentas de IR; debêntures não têm IOF. "
                + "No vencimento o título para de render e o valor é pago na conta. Toque num título para ver a conta; "
                + "deslize para resgatar (com liquidez diária ou já vencido)."
        }

        guard selectedKind == .crypto, cryptoQuotesUnavailable else { return nil }

        return "A cotação de cripto exige um plano pago da brapi. Os valores usam o preço médio informado."
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let position = self.position(at: indexPath)
        guard let fixedIncome = position.fixedIncome else {
            navigationController?.pushViewController(OperationsViewController(position: position), animated: true)
            return
        }

        let message: String
        if let breakdown = fixedIncome.breakdown {
            let matured  = fixedIncome.isMatured(on: Self.day.format(Date()))
            let maturity = fixedIncome.maturity.map { (matured ? " · venceu " : " · vence ") + Self.brazilianDate($0) } ?? ""

            let liquidity = fixedIncome.dailyLiquidity == true ? "Liquidez diária" : "Sem liquidez diária: resgate só no vencimento"

            var lines = ["\(fixedIncome.rateDescription)\(maturity)", liquidity, "", "Aplicado: \(position.invested.asCurrency)", ""]
            if matured {
                lines.append("Pago no vencimento (\(breakdown.daysHeld) dias)")
            } else {
                lines.append(fixedIncome.dailyLiquidity == true
                    ? "Resgate hoje, na curva (\(breakdown.daysHeld) dias)"
                    : "Valor hoje, na curva (\(breakdown.daysHeld) dias)")
            }
            lines += fixedIncome.lines(for: breakdown)

            if let atMaturity = fixedIncome.maturityBreakdown {
                lines += ["", fixedIncome.indexer == .prefixed
                    ? "No vencimento (\(atMaturity.daysHeld) dias)"
                    : "No vencimento (\(atMaturity.daysHeld) dias, estimado com o CDI de hoje)"]
                lines += fixedIncome.lines(for: atMaturity)
            }

            message = lines.joined(separator: "\n")
        } else {
            message = "O rendimento é calculado com o CDI do Banco Central ao atualizar a carteira. Puxe a lista para atualizar."
        }

        let alert = UIAlertController(title: position.name ?? fixedIncome.product.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TickerCell.reuseIdentifier, for: indexPath) as? TickerCell else {
            return UITableViewCell()
        }

        let position = self.position(at: indexPath)
        let quantity = position.quantity.formatted(.number.precision(.fractionLength(0...4)).locale(Locale(identifier: "pt_BR")))

        if position.isClosed {
            let sales = position.sales?.count ?? 0
            cell.configure(symbol: position.name ?? position.symbol,
                           subtitle: "Encerrada · \(sales) \(sales == 1 ? "venda" : "vendas") · lucro realizado",
                           value: position.realizedProfit, changePercent: nil, logoUrl: position.logoUrl)
            return cell
        }

        cell.configure(
            symbol: position.name ?? position.symbol,
            subtitle: position.fixedIncome.map { fixedIncome in
                guard let maturity = fixedIncome.maturity else { return "\(fixedIncome.rateDescription) · aplicado \(position.invested.asCurrency)" }
                if fixedIncome.isMatured(on: Self.day.format(Date())) {
                    return "Venceu em \(Self.brazilianDate(maturity)) · pago na conta"
                }
                return fixedIncome.dailyLiquidity == true
                    ? "\(fixedIncome.rateDescription) · liquidez diária"
                    : "\(fixedIncome.rateDescription) · vence \(Self.brazilianDate(maturity))"
            } ?? "\(quantity) × PM \(position.averagePrice.asCurrency)",
            value: position.currentValue,
            changePercent: position.resultPercent,
            logoUrl: position.logoUrl
        )

        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let position = self.position(at: indexPath)

        let remove = UIContextualAction(style: .destructive, title: "Remover") { [weak self] _, _, completion in
            PortfolioStore.remove(position)
            // Na seção de encerradas, a última linha leva a seção junto: recarrega tudo em vez de animar.
            self?.reload(deletedRow: indexPath.section == 0 ? indexPath : nil)
            completion(true)
        }
        remove.image = UIImage(systemName: "trash")

        if !position.isClosed, position.kind.isSellable {
            let sell = UIContextualAction(style: .normal, title: "Vender") { [weak self] _, _, completion in
                self?.sell(position)
                completion(true)
            }
            sell.image           = UIImage(systemName: "arrow.up.right")
            sell.backgroundColor = UIColor(named: "BrandGreen")
            return UISwipeActionsConfiguration(actions: [remove, sell])
        }

        guard position.fixedIncome != nil else { return UISwipeActionsConfiguration(actions: [remove]) }

        let redeem = UIContextualAction(style: .normal, title: "Resgatar") { [weak self] _, _, completion in
            self?.redeem(position)
            completion(true)
        }
        redeem.image           = UIImage(systemName: "arrow.down.to.line")
        redeem.backgroundColor = UIColor(named: "BrandGreen")

        return UISwipeActionsConfiguration(actions: [remove, redeem])
    }

    private func sell(_ position: PositionEntity) {
        let form    = SellPositionViewController(position: position)
        // Venda com data antiga muda as cotas com direito a proventos já pagos: recalcula tudo.
        form.onSave = { [weak self] in
            self?.reload()
            self?.refreshQuotes()
        }
        present(UINavigationController(rootViewController: form), animated: true)
    }

    private func redeem(_ position: PositionEntity) {
        guard let fixedIncome = position.fixedIncome else { return }

        guard fixedIncome.canRedeem(on: Self.day.format(Date())) else {
            let maturity = fixedIncome.maturity.map { " (\(Self.brazilianDate($0)))" } ?? ""
            let alert    = UIAlertController(title: "Sem liquidez diária",
                                             message: "Este título só pode ser resgatado no vencimento\(maturity).",
                                             preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            return present(alert, animated: true)
        }

        guard let form = RedeemFixedIncomeViewController(position: position) else { return }
        form.onRedeem = { [weak self] in self?.reload() }

        present(UINavigationController(rootViewController: form), animated: true)
    }
}

enum PortfolioQuotes {
    /// Busca exata pelo símbolo no /tickers (a busca da brapi também devolve símbolos parecidos).
    static func stock(symbol: String) async throws -> StockEntity? {
        try await ApiService.shared.getAllTickers(for: 1, search: symbol, kind: nil).results.first { $0.symbol == symbol }
    }
}
