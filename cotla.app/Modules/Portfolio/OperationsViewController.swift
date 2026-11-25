//
//  OperationsViewController.swift
//  cotla.app
//

import UIKit

/// Compras e vendas de um ativo, da mais recente para a mais antiga, com o lucro de cada venda.
final class OperationsViewController: UITableViewController {

    private struct Row {
        let date: String
        let title: String
        let detail: String
        let profit: Double?
        /// Índice em `position.sales`, quando a linha é uma venda que ainda dá para desfazer.
        let undoableSale: Int?
    }

    private static let brazilLocale = Locale(identifier: "pt_BR")

    private let kind: AssetKind
    private let symbol: String
    private var position: PositionEntity?
    private var rows: [Row] = []

    init(position: PositionEntity) {
        kind   = position.kind
        symbol = position.symbol
        super.init(style: .insetGrouped)
        title  = position.name ?? position.symbol
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "operation")
        tableView.allowsSelection = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        position = PortfolioStore.all().first { $0.kind == kind && $0.symbol == symbol }
        guard let position else { return }

        let lastBuy = position.lots?.map(\.date).max() ?? ""

        let buys = (position.lots ?? []).map { lot in
            Row(date: lot.date, title: "Compra · \(Self.quantityText(lot.quantity))",
                detail: Self.brazilianDate(lot.date) + (lot.price.map { " · \($0.asCurrency) por cota" } ?? ""),
                profit: nil, undoableSale: nil)
        }

        let sales = (position.sales ?? []).enumerated().map { index, sale in
            Row(date: sale.date, title: "Venda · \(Self.quantityText(sale.quantity))",
                detail: "\(Self.brazilianDate(sale.date)) · \(sale.price.asCurrency) por cota · PM \(sale.averagePrice.asCurrency)"
                    + (sale.fees > 0 ? " · custos \(sale.fees.asCurrency)" : ""),
                profit: sale.profit, undoableSale: sale.date >= lastBuy ? index : nil)
        }

        // Vendas primeiro no mesmo dia, já que a lista vai da mais recente para a mais antiga.
        rows = (buys + sales).sorted { ($0.date, $0.profit == nil ? 0 : 1) > ($1.date, $1.profit == nil ? 0 : 1) }

        // Cripto entra sem data de compra.
        if position.lots?.isEmpty != false {
            let bought = position.quantity + (position.sales ?? []).reduce(0) { $0 + $1.quantity }
            rows.append(Row(date: "", title: "Compras sem data · \(Self.quantityText(bought))",
                            detail: "Preço médio \(position.averagePrice.asCurrency)", profit: nil, undoableSale: nil))
        }

        navigationItem.rightBarButtonItem = position.isClosed || !position.kind.isSellable
            ? nil
            : UIBarButtonItem(title: "Vender", primaryAction: UIAction { [weak self] _ in self?.sell() })
        navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BrandGreen")

        tableView.reloadData()
    }

    private func sell() {
        guard let position else { return }

        let form    = SellPositionViewController(position: position)
        form.onSave = { [weak self] in self?.reload() }
        present(UINavigationController(rootViewController: form), animated: true)
    }

    // MARK: - Tabela

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let position else { return nil }

        let holding  = position.isClosed
            ? "Encerrada"
            : "\(Self.quantityText(position.quantity)) a preço médio \(position.averagePrice.asCurrency)"
        let realized = position.sales?.isEmpty == false ? " · Lucro realizado \(Self.signed(position.realizedProfit))" : ""

        return holding + realized
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        rows.contains { $0.undoableSale != nil } ? "Deslize uma venda para desfazer." : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "operation", for: indexPath)
        let row  = rows[indexPath.row]
        let font = UIFont.preferredFont(forTextStyle: .subheadline)

        let detail = NSMutableAttributedString(string: row.detail, attributes: [.foregroundColor: UIColor.secondaryLabel, .font: font])
        if let profit = row.profit {
            detail.append(NSAttributedString(
                string: "\n\(profit >= 0 ? "Lucro" : "Prejuízo") \(abs(profit).asCurrency)",
                attributes: [.foregroundColor: profit >= 0 ? UIColor.systemGreen : UIColor.systemRed, .font: font]
            ))
        }

        var content                     = UIListContentConfiguration.subtitleCell()
        content.text                    = row.title
        content.secondaryAttributedText = detail
        content.textToSecondaryTextVerticalPadding = 4
        cell.contentConfiguration = content

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let index = rows[indexPath.row].undoableSale, let position else { return nil }

        let undo = UIContextualAction(style: .destructive, title: "Desfazer venda") { [weak self] _, _, completion in
            PortfolioStore.undoSale(at: index, of: position)
            self?.reload()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [undo])
    }

    // MARK: - Formatação

    private static func quantityText(_ quantity: Double) -> String {
        quantity.formatted(.number.precision(.fractionLength(0...8)).locale(brazilLocale))
    }

    private static func signed(_ value: Double) -> String {
        (value >= 0 ? "+" : "-") + abs(value).asCurrency
    }

    /// "2026-12-21" → "21/12/2026"
    private static func brazilianDate(_ iso: String) -> String {
        iso.split(separator: "-").reversed().joined(separator: "/")
    }
}
