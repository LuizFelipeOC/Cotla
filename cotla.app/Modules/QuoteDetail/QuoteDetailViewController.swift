//
//  QuoteDetailViewController.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit


class QuoteDetailViewController: UIViewController, QuoteDetailViewProtocol {

    var presenter: QuoteDetailPresenterProtocol!

    let ticker: StockEntity!

    private let brazilLocale = Locale(identifier: "pt_BR")

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()

        presenter.viewDidLoad()
    }

    init(ticker: StockEntity) {
        self.ticker = ticker
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor                 = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints  = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(mainStack)
        contentView.addSubview(chartCard)
        contentView.addSubview(dividendsCard)

        setupLayoutConstrains()
    }

    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    private let chartCard     = PriceChartCardView()
    private let dividendsCard = DividendsCardView()

    // MARK: - QuoteDetailViewProtocol

    func showChartLoading() {
        chartCard.showLoading()
    }

    func displayChart(prices: [HistoricalPriceEntity]) {
        chartCard.display(prices: prices)
    }

    func displayChartError(message: String) {
        chartCard.displayError(message: message)
    }

    func showDividendsLoading() {
        dividendsCard.showLoading()
    }

    func displayDividends(_ dividends: [CashDividendEntity]) {
        dividendsCard.display(dividends: dividends)
    }

    func displayDividendsError(message: String) {
        dividendsCard.displayError(message: message)
    }

    private var isPositive: Bool {
        ticker.quote.changePercent >= 0
    }

    private var changeColor: UIColor {
        isPositive ? .systemGreen : .systemRed
    }

    private lazy var logoImageView: StockImageView = {
        let imageView = StockImageView()
        imageView.layer.cornerRadius = 16
        imageView.setImage(for: ticker.logoUrl)

        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let titleLabel  = TitleLabelView(textAligment: .left, fontSize: 26)
        titleLabel.text = ticker.symbol

        return titleLabel
    }()

    private lazy var subtitleLabel: UILabel = {
        let subtitleLabel       = SecondayLabelView(textAligment: .left, fontSize: 15)
        subtitleLabel.text      = ticker.longName
        subtitleLabel.textColor = .secondaryLabel

        return subtitleLabel
    }()

    private lazy var priceLabel: UILabel = {
        let priceLabel  = TitleLabelView(textAligment: .left, fontSize: 44)
        priceLabel.text = ticker.quote.lastPrice.asCurrency

        return priceLabel
    }()

    private lazy var changeBadge: UILabel = {
        let badge   = SecondayLabelView(textAligment: .center, fontSize: 15)
        let percent = (abs(ticker.quote.changePercent) / 100).formatted(.percent.precision(.fractionLength(2)).locale(brazilLocale))

        badge.text                  = "\(isPositive ? "▲" : "▼") \(percent)"
        badge.font                  = .systemFont(ofSize: 15, weight: .semibold)
        badge.textColor             = changeColor
        badge.backgroundColor       = changeColor.withAlphaComponent(0.15)
        badge.layer.cornerRadius    = 15
        badge.layer.cornerCurve     = .continuous
        badge.clipsToBounds         = true

        return badge
    }()

    private lazy var changeValueLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .left, fontSize: 14)
        let lastPrice       = ticker.quote.lastPrice
        let previousClose   = lastPrice / (1 + ticker.quote.changePercent / 100)
        let difference      = abs(lastPrice - previousClose).asCurrency

        label.text      = "\(isPositive ? "+" : "-")\(difference) hoje"
        label.font      = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = changeColor

        return label
    }()

    private lazy var headerStack: UIStackView = {
        let textStack       = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis      = .vertical
        textStack.spacing   = 4

        let stack       = UIStackView(arrangedSubviews: [logoImageView, textStack])
        stack.axis      = .horizontal
        stack.alignment = .center
        stack.spacing   = 14

        return stack
    }()

    private lazy var chipsStack: UIStackView = {
        var chips = [makeChip(text: assetTypeText)]

        if let subsector = ticker.subsector {
            chips.append(makeChip(text: subsector))
        }

        let stack       = UIStackView(arrangedSubviews: chips)
        stack.axis      = .horizontal
        stack.spacing   = 8

        return stack
    }()

    private lazy var priceStack: UIStackView = {
        let stack       = UIStackView(arrangedSubviews: [priceLabel, changeBadge])
        stack.axis      = .horizontal
        stack.alignment = .center
        stack.spacing   = 12

        return stack
    }()

    private lazy var mainStack: UIStackView = {
        let stack       = UIStackView(arrangedSubviews: [headerStack, chipsStack, priceStack, changeValueLabel])
        stack.axis      = .vertical
        stack.alignment = .leading
        stack.spacing   = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.setCustomSpacing(14, after: headerStack)
        stack.setCustomSpacing(18, after: chipsStack)

        return stack
    }()

    private var assetTypeText: String {
        switch ticker.assetType {
        case "stock": return "Ação"
        case "fund":  return "Fundo"
        case "bdr":   return "BDR"
        default:      return ticker.assetType.capitalized
        }
    }

    private func makeChip(text: String) -> UILabel {
        let chip                = SecondayLabelView(textAligment: .center, fontSize: 13)
        chip.text               = text
        chip.textColor          = .secondaryLabel
        chip.backgroundColor    = .systemGray5
        chip.layer.cornerRadius = 13
        chip.clipsToBounds      = true

        NSLayoutConstraint.activate([
            chip.widthAnchor.constraint(equalToConstant: chip.intrinsicContentSize.width + 24),
            chip.heightAnchor.constraint(equalToConstant: 26)
        ])

        return chip
    }

    private func setupLayoutConstrains() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),

            changeBadge.widthAnchor.constraint(equalToConstant: changeBadge.intrinsicContentSize.width + 28),
            changeBadge.heightAnchor.constraint(equalToConstant: 30),

            chartCard.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: 24),
            chartCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            chartCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            dividendsCard.topAnchor.constraint(equalTo: chartCard.bottomAnchor, constant: 16),
            dividendsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dividendsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dividendsCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
}
