//
//  DividendsCardView.swift
//  cotla.app
//

import UIKit

final class DividendsCardView: CardView {

    private static let brazilLocale = Locale(identifier: "pt_BR")

    private static let paymentDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter    = DateFormatter()
        formatter.locale = brazilLocale
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private let titleLabel       = TitleLabelView(textAligment: .left, fontSize: 17)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let messageLabel     = SecondayLabelView(textAligment: .center, fontSize: 14)
    private let rowsStack        = UIStackView()

    private static let collapsedCount = 5
    private var dividends: [CashDividendEntity] = []

    /// Quando `true`, lista todos os itens sem o botão "Ver mais" (usado na sheet).
    var showsAll = false
    var onShowMore: (([CashDividendEntity]) -> Void)?

    required init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showLoading() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowsStack.isHidden    = true
        messageLabel.isHidden = true
        loadingIndicator.startAnimating()
    }

    func display(dividends: [CashDividendEntity]) {
        self.dividends = dividends
        loadingIndicator.stopAnimating()
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !dividends.isEmpty else {
            messageLabel.text     = "Nenhum dividendo encontrado para este ativo"
            messageLabel.isHidden = false
            rowsStack.isHidden    = true
            return
        }

        messageLabel.isHidden = true
        rowsStack.isHidden    = false

        let visible = showsAll ? dividends : Array(dividends.prefix(Self.collapsedCount))

        for (index, dividend) in visible.enumerated() {
            if index > 0 {
                rowsStack.addArrangedSubview(makeSeparator())
            }

            rowsStack.addArrangedSubview(makeRow(for: dividend))
        }

        if visible.count < dividends.count {
            rowsStack.addArrangedSubview(makeShowMoreButton())
        }
    }

    private func makeShowMoreButton() -> UIButton {
        var configuration   = UIButton.Configuration.plain()
        configuration.title = "Ver mais"

        return UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            onShowMore?(dividends)
        })
    }

    func displayError(message: String) {
        loadingIndicator.stopAnimating()
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowsStack.isHidden = true

        messageLabel.text     = message
        messageLabel.isHidden = false
    }

    // MARK: - Layout

    private func setupViews() {
        titleLabel.text = "Dividendos"

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true

        messageLabel.textColor     = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.isHidden      = true

        rowsStack.axis    = .vertical
        rowsStack.spacing = 12
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(loadingIndicator)
        addSubview(messageLabel)
        addSubview(rowsStack)

        setupLayoutConstrains()
    }

    private func makeRow(for dividend: CashDividendEntity) -> UIView {
        let typeLabel       = SecondayLabelView(textAligment: .left, fontSize: 13)
        typeLabel.text      = typeText(for: dividend)
        typeLabel.textColor = .label
        typeLabel.font      = .systemFont(ofSize: 13, weight: .semibold)

        let dateLabel  = SecondayLabelView(textAligment: .left, fontSize: 12)
        dateLabel.text = dateText(for: dividend)

        let textStack     = UIStackView(arrangedSubviews: [typeLabel, dateLabel])
        textStack.axis    = .vertical
        textStack.spacing = 2

        let valueLabel           = SecondayLabelView(textAligment: .right, fontSize: 15)
        valueLabel.text          = dividend.rate.asCurrency
        valueLabel.textColor     = .label
        valueLabel.font          = .systemFont(ofSize: 15, weight: .semibold)

        let rowStack       = UIStackView(arrangedSubviews: [textStack, valueLabel])
        rowStack.axis      = .horizontal
        rowStack.alignment = .center
        rowStack.spacing   = 8

        return rowStack
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        return separator
    }

    private func dateText(for dividend: CashDividendEntity) -> String {
        guard let raw = dividend.paymentDate ?? dividend.exDate,
              let date = Self.paymentDateFormatter.date(from: raw) else {
            return "Data não informada"
        }

        return Self.displayDateFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func typeText(for dividend: CashDividendEntity) -> String {
        switch dividend.label?.uppercased() {
        case "JCP":        return "JCP"
        case "DIVIDENDO":  return "Dividendo"
        case "RENDIMENTO": return "Rendimento"
        default:           return dividend.label?.capitalized ?? "Provento"
        }
    }

    private func setupLayoutConstrains() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            // rowsStack define a altura do card; os demais apenas se centralizam na mesma faixa,
            // então funcionam mesmo quando o stack está vazio (carregando ou com erro).
            rowsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            rowsStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: rowsStack.centerYAnchor),

            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.centerYAnchor.constraint(equalTo: rowsStack.centerYAnchor)
        ])
    }
}
