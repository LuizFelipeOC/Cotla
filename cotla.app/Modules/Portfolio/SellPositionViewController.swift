//
//  SellPositionViewController.swift
//  cotla.app
//

import UIKit

/// Venda de ações, FIIs, ETFs e cripto. O lucro segue a regra do preço médio:
/// (quantidade × preço − custos) − quantidade × PM. Vender não muda o PM das cotas que ficam.
final class SellPositionViewController: UIViewController {

    var onSave: (() -> Void)?

    /// Fuso do aparelho: é nele que o seletor devolve o dia escolhido.
    private static let marketDay    = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
    private static let brazilLocale = Locale(identifier: "pt_BR")

    private let position: PositionEntity
    private var priceTask: Task<Void, Never>?

    init(position: PositionEntity) {
        self.position = position
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title                = "Vender \(position.name ?? position.symbol)"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem  = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Vender", style: .done, target: self, action: #selector(confirm))
        navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BrandGreen")
        navigationItem.rightBarButtonItem?.isEnabled = false

        datePicker.minimumDate = position.lots?.map(\.date).min().flatMap { try? Date($0, strategy: Self.marketDay) }
        datePicker.maximumDate = Date()

        view.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            formStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        quantityField.becomeFirstResponder()
        fillPrice()
        updatePreview()
    }

    // MARK: - Views

    private lazy var datePicker: UIDatePicker = {
        let picker                      = UIDatePicker()
        picker.datePickerMode           = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale                   = Self.brazilLocale
        picker.tintColor                = UIColor(named: "BrandGreen")
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        return picker
    }()

    private lazy var dateRow: UIStackView = {
        let label       = SecondayLabelView(textAligment: .left, fontSize: 17)
        label.text      = "Data da venda"
        label.textColor = .label

        let row       = UIStackView(arrangedSubviews: [label, datePicker])
        row.axis      = .horizontal
        row.alignment = .center
        return row
    }()

    private lazy var quantityField: UITextField = {
        let field = makeField(placeholder: "Quantidade (você tem \(Self.quantityText(position.quantity)))", keyboard: .decimalPad)
        field.addTarget(self, action: #selector(updatePreview), for: .editingChanged)
        return field
    }()

    private lazy var allButton: UIButton = {
        var configuration                 = UIButton.Configuration.plain()
        configuration.title               = "Vender tudo"
        configuration.baseForegroundColor = UIColor(named: "BrandGreen")

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            quantityField.text = Self.quantityText(position.quantity)
            updatePreview()
        }, for: .primaryActionTriggered)
        return button
    }()

    private lazy var priceField: UITextField = {
        let field      = makeField(placeholder: "Preço (R$ 0,00)", keyboard: .numberPad)
        field.delegate = self
        return field
    }()

    /// Corretagem, emolumentos etc. Reduzem o valor da venda e o lucro.
    private lazy var feesField: UITextField = {
        let field      = makeField(placeholder: "Custos da venda (R$ 0,00)", keyboard: .numberPad)
        field.delegate = self
        return field
    }()

    private let previewLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .left, fontSize: 15)
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var formStack: UIStackView = {
        let stack     = UIStackView(arrangedSubviews: [dateRow, quantityField, allButton, priceField, feesField, previewLabel])
        stack.axis    = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private func makeField(placeholder: String, keyboard: UIKeyboardType) -> UITextField {
        let field          = UITextField()
        field.placeholder  = placeholder
        field.keyboardType = keyboard
        field.borderStyle  = .roundedRect
        field.font         = .systemFont(ofSize: 17)
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return field
    }

    // MARK: - Venda

    private var day: String { Self.marketDay.format(datePicker.date) }

    /// Aceita vírgula ou ponto como separador decimal.
    private var quantity: Double {
        Double(quantityField.text?.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0
    }

    /// nil enquanto faltar dado ou a quantidade passar do que havia na data.
    private var sale: PositionEntity.Sale? {
        guard let price = CurrencyMask.value(of: priceField), price > 0, position.canSell(quantity, on: day) else { return nil }

        return PositionEntity.Sale(date: day, quantity: quantity, price: price,
                                   fees: CurrencyMask.value(of: feesField) ?? 0, averagePrice: position.averagePrice)
    }

    @objc private func dateChanged() {
        fillPrice()
        updatePreview()
    }

    /// Ações, FIIs e ETFs: fechamento do dia escolhido. Cripto: última cotação. Dá para trocar pelo preço da nota.
    private func fillPrice() {
        guard position.kind.isListedOnB3 else {
            if priceField.text?.isEmpty != false, let price = position.currentPrice {
                priceField.text = price.asCurrency
            }
            return
        }

        let date = datePicker.date
        priceTask?.cancel()
        priceTask = Task {
            guard let close = try? await AddPositionViewController.closePrice(symbol: position.symbol, on: date),
                  !Task.isCancelled else { return }
            priceField.text = close.asCurrency
            updatePreview()
        }
    }

    @objc private func updatePreview() {
        let owned = "Você tem \(Self.quantityText(position.quantity)) a preço médio \(position.averagePrice.asCurrency)."

        guard quantity > 0 else {
            previewLabel.text = owned
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }

        guard position.canSell(quantity, on: day) else {
            previewLabel.text = "\(owned)\n\nA quantidade passa do que você tinha nessa data (ou deixaria uma venda posterior sem cotas)."
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }

        guard let sale else {
            previewLabel.text = owned
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }

        let cost      = sale.quantity * sale.averagePrice
        let percent   = (sale.profit / cost).formatted(.percent.precision(.fractionLength(2)).locale(Self.brazilLocale))
        let remaining = position.quantity - sale.quantity

        var lines = [
            "Valor da venda: \(sale.proceeds.asCurrency)",
            "Custo pelo preço médio: \(cost.asCurrency)",
            "\(sale.profit >= 0 ? "Lucro" : "Prejuízo"): \(abs(sale.profit).asCurrency) (\(sale.profit >= 0 ? "+" : "")\(percent))",
            ""
        ]
        lines.append(remaining > 1e-9
            ? "Ficam \(Self.quantityText(remaining)) a preço médio \(position.averagePrice.asCurrency) (vender não muda o PM)."
            : "A posição fica encerrada, com o histórico guardado.")

        previewLabel.text = lines.joined(separator: "\n")
        navigationItem.rightBarButtonItem?.isEnabled = true
    }

    @objc private func confirm() {
        guard let sale else { return }

        PortfolioStore.sell(sale, of: position)
        onSave?()
        dismiss(animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    /// Sem separador de milhar, para "Vender tudo" voltar a ser lido pelo campo.
    private static func quantityText(_ quantity: Double) -> String {
        quantity.formatted(.number.grouping(.never).precision(.fractionLength(0...8)).locale(brazilLocale))
    }
}

extension SellPositionViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        defer { updatePreview() }
        return CurrencyMask.apply(to: textField, range: range, replacement: string)
    }
}
