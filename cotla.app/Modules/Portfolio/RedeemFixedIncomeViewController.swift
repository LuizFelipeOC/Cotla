//
//  RedeemFixedIncomeViewController.swift
//  cotla.app
//

import UIKit

/// Resgate total ou parcial de renda fixa, com bruto, IOF, IR e líquido antes de confirmar.
/// O que fica aplicado continua rendendo com a data original, então o IR dele segue os dias desde a aplicação.
final class RedeemFixedIncomeViewController: UIViewController {

    var onRedeem: (() -> Void)?

    /// Fuso do aparelho: é nele que o seletor devolve o dia escolhido.
    private static let marketDay = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()

    private let position: PositionEntity
    private let fixedIncome: FixedIncome
    private let appliedOn: String
    private var cdiDays: [CdiDayEntity]?

    init?(position: PositionEntity) {
        guard let fixedIncome = position.fixedIncome, let appliedOn = position.lots?.first?.date else { return nil }

        self.position    = position
        self.fixedIncome = fixedIncome
        self.appliedOn   = appliedOn
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title                = "Resgatar \(position.name ?? fixedIncome.product.title)"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem  = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Resgatar", style: .done, target: self, action: #selector(confirm))
        navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BrandGreen")
        navigationItem.rightBarButtonItem?.isEnabled = false

        // Sem liquidez diária, o resgate só existe a partir do vencimento.
        let earliest = fixedIncome.dailyLiquidity == true ? appliedOn : (fixedIncome.maturity ?? appliedOn)
        datePicker.minimumDate = try? Date(earliest, strategy: Self.marketDay)
        datePicker.maximumDate = Date()

        view.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            formStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        amountField.becomeFirstResponder()
        loadCdi()
    }

    // MARK: - Views

    private lazy var datePicker: UIDatePicker = {
        let picker                      = UIDatePicker()
        picker.datePickerMode           = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale                   = Locale(identifier: "pt_BR")
        picker.tintColor                = UIColor(named: "BrandGreen")
        picker.addTarget(self, action: #selector(updatePreview), for: .valueChanged)
        return picker
    }()

    private lazy var dateRow: UIStackView = {
        let label       = SecondayLabelView(textAligment: .left, fontSize: 17)
        label.text      = "Data do resgate"
        label.textColor = .label

        let row       = UIStackView(arrangedSubviews: [label, datePicker])
        row.axis      = .horizontal
        row.alignment = .center
        return row
    }()

    private lazy var modeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Quero receber (líquido)", "Valor bruto"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(updatePreview), for: .valueChanged)
        return control
    }()

    private lazy var amountField: UITextField = {
        let field          = UITextField()
        field.placeholder  = "Valor (R$ 0,00)"
        field.keyboardType = .numberPad
        field.borderStyle  = .roundedRect
        field.font         = .systemFont(ofSize: 17)
        field.delegate     = self
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return field
    }()

    private lazy var allButton: UIButton = {
        var configuration       = UIButton.Configuration.plain()
        configuration.title     = "Resgatar tudo"
        configuration.baseForegroundColor = UIColor(named: "BrandGreen")

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: #selector(fillAll), for: .touchUpInside)
        return button
    }()

    private let previewLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .left, fontSize: 15)
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var formStack: UIStackView = {
        let stack     = UIStackView(arrangedSubviews: [dateRow, modeControl, amountField, allButton, previewLabel])
        stack.axis    = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Cálculo

    private var day: String { Self.marketDay.format(datePicker.date) }
    private var isNet: Bool { modeControl.selectedSegmentIndex == 0 }

    private func loadCdi() {
        previewLabel.text = "Carregando CDI do Banco Central…"

        Task {
            let today = Self.marketDay.format(Date())

            // Sem dia útil desde a aplicação o BCB não devolve nada, e também não há rendimento.
            if BusinessDays.count(from: appliedOn, to: today) == 0 {
                cdiDays = []
            } else {
                cdiDays = try? await ApiService.shared.getCdi(startDate: Self.brazilianDate(appliedOn), endDate: Self.brazilianDate(today))
            }

            guard cdiDays != nil else {
                previewLabel.text = "Não foi possível carregar o CDI do Banco Central. Feche e tente de novo."
                return
            }
            updatePreview()
        }
    }

    private func redemption(of amount: Double) -> (redeemed: FixedIncome.Breakdown, remainingFraction: Double)? {
        guard let cdiDays else { return nil }
        return fixedIncome.partialRedemption(of: amount, isNet: isNet, invested: position.invested,
                                             appliedOn: appliedOn, on: day, cdi: cdiDays)
    }

    @objc private func updatePreview() {
        guard let cdiDays else { return }

        let full   = fixedIncome.redemption(invested: position.invested, appliedOn: appliedOn, on: day, cdi: cdiDays)
        let amount = CurrencyMask.value(of: amountField) ?? 0
        let result = redemption(of: amount)

        var lines = ["Saldo em \(Self.brazilianDate(day)): líquido \(full.net.asCurrency) · bruto \(full.gross.asCurrency)"]

        if let result {
            lines += ["", "Neste resgate (\(result.redeemed.daysHeld) dias desde a aplicação):"]
            lines += fixedIncome.lines(for: result.redeemed)
            lines += ["", result.remainingFraction > 0
                ? "Continua aplicado: \((position.invested * result.remainingFraction).asCurrency) do valor investido, "
                    + "rendendo e contando o IR desde \(Self.brazilianDate(appliedOn))."
                : "O título sai da carteira."]
        } else if amount > 0 {
            lines += ["", "O valor passa do saldo."]
        }

        previewLabel.text = lines.joined(separator: "\n")
        navigationItem.rightBarButtonItem?.isEnabled = result != nil
    }

    @objc private func fillAll() {
        guard let cdiDays else { return }

        let full = fixedIncome.redemption(invested: position.invested, appliedOn: appliedOn, on: day, cdi: cdiDays)
        amountField.text = (isNet ? full.net : full.gross).asCurrency
        updatePreview()
    }

    @objc private func confirm() {
        guard let amount = CurrencyMask.value(of: amountField), let result = redemption(of: amount) else { return }

        if result.remainingFraction == 0 {
            PortfolioStore.remove(position)
        } else {
            // Tudo é proporcional ao valor investido: a parte que fica vale a mesma fração de hoje e do vencimento.
            let keep    = result.remainingFraction
            var updated = position
            updated.averagePrice                    = position.averagePrice * keep
            updated.currentPrice                    = position.currentPrice.map { $0 * keep }
            updated.fixedIncome?.breakdown          = fixedIncome.breakdown?.scaled(by: keep)
            updated.fixedIncome?.maturityBreakdown  = fixedIncome.maturityBreakdown?.scaled(by: keep)

            PortfolioStore.save(PortfolioStore.all().map {
                $0.symbol == position.symbol && $0.kind == position.kind ? updated : $0
            })
        }

        onRedeem?()
        dismiss(animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    /// "2026-12-21" → "21/12/2026"
    private static func brazilianDate(_ iso: String) -> String {
        iso.split(separator: "-").reversed().joined(separator: "/")
    }
}

extension RedeemFixedIncomeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        defer { updatePreview() }
        return CurrencyMask.apply(to: textField, range: range, replacement: string)
    }
}
