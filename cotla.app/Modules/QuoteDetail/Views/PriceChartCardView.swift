//
//  PriceChartCardView.swift
//  cotla.app
//

import UIKit

final class PriceChartCardView: CardView {

    private static let brazilLocale = Locale(identifier: "pt_BR")

    private let chartView        = PriceChartView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let messageLabel     = SecondayLabelView(textAligment: .center, fontSize: 14)
    private let separatorView    = UIView()

    private let openValueLabel   = TitleLabelView(textAligment: .center, fontSize: 16)
    private let highValueLabel   = TitleLabelView(textAligment: .center, fontSize: 16)
    private let lowValueLabel    = TitleLabelView(textAligment: .center, fontSize: 16)
    private let volumeValueLabel = TitleLabelView(textAligment: .center, fontSize: 16)

    required init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showLoading() {
        messageLabel.isHidden = true
        loadingIndicator.startAnimating()

        UIView.animate(withDuration: 0.2) {
            self.chartView.alpha = 0.35
        }
    }

    func display(prices: [HistoricalPriceEntity]) {
        let points = prices.compactMap { price -> PriceChartView.Point? in
            guard let close = price.close else { return nil }
            return PriceChartView.Point(date: Date(timeIntervalSince1970: price.date), price: close)
        }

        loadingIndicator.stopAnimating()
        messageLabel.isHidden = true
        chartView.alpha       = 1
        chartView.setPoints(points, animated: true)

        updateStats(with: prices)
    }

    func displayError(message: String) {
        loadingIndicator.stopAnimating()
        chartView.alpha = 1
        chartView.setPoints([], animated: false)

        messageLabel.text     = message
        messageLabel.isHidden = false

        updateStats(with: [])
    }

    // MARK: - Layout

    private func setupViews() {
        chartView.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true

        messageLabel.textColor     = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.isHidden      = true

        separatorView.backgroundColor = .separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(chartView)
        addSubview(loadingIndicator)
        addSubview(messageLabel)
        addSubview(separatorView)
        addSubview(statsStack)

        setupLayoutConstrains()
    }

    private lazy var statsStack: UIStackView = {
        let columns = [
            makeStatColumn(title: "Abertura", valueLabel: openValueLabel, showsDivider: false),
            makeStatColumn(title: "Máxima", valueLabel: highValueLabel, showsDivider: true),
            makeStatColumn(title: "Mínima", valueLabel: lowValueLabel, showsDivider: true),
            makeStatColumn(title: "Volume", valueLabel: volumeValueLabel, showsDivider: true)
        ]

        let stack          = UIStackView(arrangedSubviews: columns)
        stack.axis         = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        return stack
    }()

    private func makeStatColumn(title: String, valueLabel: UILabel, showsDivider: Bool) -> UIView {
        let titleLabel       = SecondayLabelView(textAligment: .center, fontSize: 12)
        titleLabel.text      = title
        titleLabel.textColor = .secondaryLabel

        valueLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        valueLabel.text = "—"

        let stack     = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis    = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let column = UIView()
        column.addSubview(stack)

        var constraints = [
            stack.topAnchor.constraint(equalTo: column.topAnchor),
            stack.bottomAnchor.constraint(equalTo: column.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: column.trailingAnchor)
        ]

        if showsDivider {
            let divider = UIView()
            divider.backgroundColor = .separator
            divider.translatesAutoresizingMaskIntoConstraints = false
            column.addSubview(divider)

            constraints += [
                divider.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                divider.centerYAnchor.constraint(equalTo: column.centerYAnchor),
                divider.widthAnchor.constraint(equalToConstant: 1),
                divider.heightAnchor.constraint(equalTo: column.heightAnchor, multiplier: 0.8)
            ]
        }

        NSLayoutConstraint.activate(constraints)

        return column
    }

    private func setupLayoutConstrains() {
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalToConstant: 250),

            loadingIndicator.centerXAnchor.constraint(equalTo: chartView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: chartView.centerYAnchor),

            messageLabel.centerYAnchor.constraint(equalTo: chartView.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: chartView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: chartView.trailingAnchor, constant: -24),

            separatorView.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 8),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),

            statsStack.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 12),
            statsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Estatísticas do período

    private func updateStats(with prices: [HistoricalPriceEntity]) {
        let valid  = prices.filter { $0.close != nil }
        let open   = valid.first.flatMap { $0.open ?? $0.close }
        let high   = valid.compactMap { $0.high ?? $0.close }.max()
        let low    = valid.compactMap { $0.low ?? $0.close }.min()
        let volume = valid.compactMap(\.volume).reduce(0, +)

        UIView.transition(with: statsStack, duration: 0.25, options: .transitionCrossDissolve) {
            self.openValueLabel.text   = self.formatPrice(open)
            self.highValueLabel.text   = self.formatPrice(high)
            self.lowValueLabel.text    = self.formatPrice(low)
            self.volumeValueLabel.text = valid.isEmpty ? "—" : self.formatVolume(volume)
        }
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.asPrice
    }

    private func formatVolume(_ volume: Double) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)).locale(Self.brazilLocale)

        switch volume {
        case 1_000_000_000...: return "\((volume / 1_000_000_000).formatted(style)) bi"
        case 1_000_000...:     return "\((volume / 1_000_000).formatted(style)) mi"
        case 1_000...:         return "\((volume / 1_000).formatted(style)) mil"
        default:               return volume.formatted(.number.precision(.fractionLength(0)).locale(Self.brazilLocale))
        }
    }
}
