//
//  AddPositionViewController.swift
//  cotla.app
//

import UIKit

class AddPositionViewController: UIViewController {

    var onSave: ((AssetKind) -> Void)?

    private let initialKind: AssetKind
    private let initialSymbol: String?
    private let displayName: String?

    /// Com `symbol`, o ativo já vem escolhido (ex.: vindo da lista de cotações) e só falta quantidade e preço.
    init(kind: AssetKind, symbol: String? = nil, displayName: String? = nil) {
        self.initialKind   = kind
        self.initialSymbol = symbol
        self.displayName   = displayName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title                = "Adicionar ativo"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem  = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Salvar", style: .done, target: self, action: #selector(save))
        navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BrandGreen")

        kindControl.selectedSegmentIndex = AssetKind.allCases.firstIndex(of: initialKind) ?? 0
        kindChanged()

        view.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            formStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        if let initialSymbol {
            title                  = "Adicionar \(displayName ?? initialSymbol)"
            symbolField.text       = initialSymbol
            kindControl.isHidden   = true
            symbolField.isHidden   = true
            (initialKind == .treasury ? priceField : quantityField).becomeFirstResponder()
            fillClosePrice()
        } else {
            symbolField.becomeFirstResponder()
        }
    }

    private lazy var kindControl: UISegmentedControl = {
        let control = UISegmentedControl(items: AssetKind.allCases.map(\.title))
        control.addTarget(self, action: #selector(kindChanged), for: .valueChanged)
        return control
    }()

    private lazy var symbolField: UITextField = {
        let field                    = Self.makeField(placeholder: "Código")
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType     = .no
        field.addTarget(self, action: #selector(fillClosePrice), for: .editingDidEnd)
        return field
    }()

    /// Corretagem, emolumentos etc. Entram no preço médio, como no Investidor10.
    private lazy var feesField: UITextField = {
        let field      = Self.makeField(placeholder: "Outros custos (R$ 0,00)", keyboard: .numberPad)
        field.delegate = self
        return field
    }()

    private var priceTask: Task<Void, Never>?

    private let quantityField = makeField(placeholder: "Quantidade", keyboard: .decimalPad)
    private lazy var priceField: UITextField = {
        let field      = Self.makeField(placeholder: "Preço médio (R$ 0,00)", keyboard: .numberPad)
        field.delegate = self
        return field
    }()

    /// Tesouro se compra por valor numa data, não por quantidade × preço.
    private lazy var purchaseDatePicker: UIDatePicker = {
        let picker                     = UIDatePicker()
        picker.datePickerMode          = .date
        picker.preferredDatePickerStyle = .compact
        picker.maximumDate             = Date()
        picker.locale                  = Locale(identifier: "pt_BR")
        picker.tintColor               = UIColor(named: "BrandGreen")
        picker.addTarget(self, action: #selector(fillClosePrice), for: .valueChanged)
        return picker
    }()

    private lazy var purchaseDateRow: UIStackView = {
        let label  = SecondayLabelView(textAligment: .left, fontSize: 17)
        label.text      = "Data da compra"
        label.textColor = .label

        let row       = UIStackView(arrangedSubviews: [label, purchaseDatePicker])
        row.axis      = .horizontal
        row.alignment = .center
        return row
    }()

    /// Campos com máscara guardam os dígitos como centavos: "R$ 12,34" → 12.34.
    private func currencyValue(of field: UITextField) -> Double? {
        Double(field.text?.filter(\.isNumber) ?? "").map { $0 / 100 }
    }

    private lazy var formStack: UIStackView = {
        let stack     = UIStackView(arrangedSubviews: [kindControl, symbolField, purchaseDateRow, quantityField, priceField, feesField])
        stack.axis    = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(20, after: kindControl)
        return stack
    }()

    private static func makeField(placeholder: String, keyboard: UIKeyboardType = .default) -> UITextField {
        let field          = UITextField()
        field.placeholder  = placeholder
        field.keyboardType = keyboard
        field.borderStyle  = .roundedRect
        field.font         = .systemFont(ofSize: 17)
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return field
    }

    @objc private func kindChanged() {
        let examples: [AssetKind: String] = [.stock: "ex.: PETR4", .fii: "ex.: HGLG11", .crypto: "ex.: BTC",
                                             .treasury: "ex.: tesouro-selic-01032031"]
        symbolField.autocapitalizationType = selectedKind == .treasury ? .none : .allCharacters
        symbolField.placeholder = "Código (\(examples[selectedKind] ?? ""))"

        // Cripto não tem histórico no plano gratuito, então não pede data; Tesouro é por valor, sem custos.
        let isTreasury           = selectedKind == .treasury
        purchaseDateRow.isHidden = selectedKind == .crypto
        quantityField.isHidden   = isTreasury
        feesField.isHidden       = isTreasury
        priceField.placeholder   = isTreasury ? "Valor investido (R$ 0,00)" : "Preço (R$ 0,00)"

        fillClosePrice()
    }

    private var currentSymbol: String {
        let typed = symbolField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        // Códigos do Tesouro são minúsculos ("tesouro-selic-01032031"); os demais, maiúsculos.
        return selectedKind == .treasury ? typed.lowercased() : typed.uppercased()
    }

    /// Preenche o preço com o fechamento do dia escolhido; o usuário pode trocar pelo que pagou.
    @objc private func fillClosePrice() {
        let symbol = currentSymbol
        let date   = purchaseDatePicker.date

        guard selectedKind == .stock || selectedKind == .fii, !symbol.isEmpty else { return }

        priceTask?.cancel()
        priceTask = Task {
            guard let close = try? await Self.closePrice(symbol: symbol, on: date), !Task.isCancelled else { return }
            priceField.text = close.asCurrency
        }
    }

    private var selectedKind: AssetKind {
        AssetKind.allCases[kindControl.selectedSegmentIndex]
    }

    /// Aceita vírgula ou ponto como separador decimal.
    private func number(from field: UITextField) -> Double? {
        Double(field.text?.replacingOccurrences(of: ",", with: ".") ?? "")
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func save() {
        let kind   = selectedKind
        let symbol = currentSymbol
        let fees   = currencyValue(of: feesField) ?? 0

        // No Tesouro o campo de preço é o valor investido e a quantidade sai do preço do título na data.
        let quantity = kind == .treasury ? 0 : (number(from: quantityField) ?? 0)

        guard !symbol.isEmpty,
              kind == .treasury || quantity > 0,
              let price = currencyValue(of: priceField), price > 0 else {
            return showAlert(kind == .treasury
                ? "Preencha o valor investido."
                : "Preencha o código, a quantidade e o preço médio com valores maiores que zero.")
        }

        let purchaseDate = purchaseDatePicker.date

        navigationItem.rightBarButtonItem?.isEnabled = false

        Task {
            defer { navigationItem.rightBarButtonItem?.isEnabled = true }

            // Custos entram no custo total: PM = (quantidade × preço + custos) ÷ quantidade.
            let averagePrice = kind == .treasury ? price : (quantity * price + fees) / quantity
            var position     = PositionEntity(symbol: symbol, kind: kind, quantity: quantity, averagePrice: averagePrice)

            do {
                switch kind {
                case .stock, .fii:
                    guard let stock = try await PortfolioQuotes.stock(symbol: symbol) else {
                        return showAlert("\(symbol) não foi encontrado na B3.")
                    }

                    let isFii = stock.subType == "fii"
                    guard isFii == (kind == .fii) else {
                        return showAlert(isFii ? "\(symbol) é um FII. Adicione em FIIs." : "\(symbol) não é um FII. Adicione em Ações.")
                    }

                    position.currentPrice = stock.quote.lastPrice
                    position.logoUrl      = stock.logoUrl

                case .treasury:
                    guard let bond = try await ApiService.shared.getTreasury(page: 1, search: symbol).results.first(where: { $0.symbol == symbol }) else {
                        return showAlert("Título \(symbol) não encontrado.")
                    }

                    guard let unitPrice = try await Self.treasuryBuyPrice(symbol: symbol, on: purchaseDate) else {
                        return showAlert("Não há preço do \(bond.displayName) nessa data. Confira a data da aplicação.")
                    }

                    // Mesma conta do extrato do Tesouro: cotas = valor aplicado ÷ PU de compra do dia.
                    position.quantity     = price / unitPrice
                    position.averagePrice = unitPrice
                    // Na carteira o título vale o preço de venda (o que se recebe ao resgatar).
                    position.currentPrice = bond.sellPrice
                    position.name         = bond.displayName

                case .crypto:
                    do {
                        guard let coin = try await ApiService.shared.getCrypto(coins: [symbol]).coins.first else {
                            return showAlert("\(symbol) não foi encontrada.")
                        }

                        position.currentPrice = coin.regularMarketPrice
                        position.logoUrl      = coin.coinImageUrl
                    } catch CotlaError.paidFeatureRequired, CotlaError.unauthorized {
                        // Sem plano pago não dá para validar nem cotar: salva só com o preço médio.
                    }
                }
            } catch {
                return showAlert("Não foi possível validar o ativo agora. Tente novamente.")
            }

            if kind != .crypto {
                position.lots = [.init(date: Self.marketDay.format(purchaseDate), quantity: position.quantity)]
            }

            PortfolioStore.add(position)
            onSave?(kind)
            dismiss(animated: true)
        }
    }

    /// Fuso do aparelho: é nele que o seletor devolve o dia escolhido.
    private static let marketDay = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()

    /// PU de compra do último dia útil até `date` (fim de semana/feriado usa o dia útil anterior).
    private static func treasuryBuyPrice(symbol: String, on date: Date) async throws -> Double? {
        let day   = marketDay.format(date)
        let start = marketDay.format(date.addingTimeInterval(-10 * 86_400))

        let history = try await ApiService.shared.getTreasuryHistory(symbol: symbol, startDate: start, endDate: day)
            .results.first?.history ?? []

        return history
            .filter { $0.baseDate <= day && $0.buyPrice != nil }
            .max { $0.baseDate < $1.baseDate }?
            .buyPrice
    }

    /// Datas do histórico vêm como meia-noite de Brasília.
    private static let saoPauloDay = Date.ISO8601FormatStyle(timeZone: TimeZone(identifier: "America/Sao_Paulo") ?? .current)
        .year().month().day()

    /// Fechamento do último pregão até `date` (fim de semana/feriado usa o pregão anterior).
    private static func closePrice(symbol: String, on date: Date) async throws -> Double? {
        let day   = marketDay.format(date)
        let start = marketDay.format(date.addingTimeInterval(-10 * 86_400))

        let prices = try await ApiService.shared.getHistorical(symbol: symbol, startDate: start, endDate: day)
            .results.first?.data.historicalDataPrice ?? []

        return prices
            .filter { $0.close != nil && saoPauloDay.format(Date(timeIntervalSince1970: $0.date)) <= day }
            .max { $0.date < $1.date }?
            .close
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension AddPositionViewController: UITextFieldDelegate {
    /// Máscara de reais: cada dígito digitado entra pela direita, como em app de banco.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = (textField.text ?? "") as NSString
        let digits  = String(current.replacingCharacters(in: range, with: string).filter(\.isNumber).prefix(13))

        textField.text = Double(digits).map { ($0 / 100).asCurrency } ?? ""
        return false
    }
}
