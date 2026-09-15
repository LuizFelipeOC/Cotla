//
//  TickerCellViewCell.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit

class TickerCell: UITableViewCell {

    static let reuseIdentifier = "TickerCell"

    private let cardView      = CardView()
    private let logoImageView = StockImageView()
    private let tickerLabel   = TitleLabelView(textAligment: .left, fontSize: 18)
    private let nameLabel     = SecondayLabelView(textAligment: .left, fontSize: 14)
    private let priceLabel    = SecondayLabelView(textAligment: .right, fontSize: 16)
    private let changeBadge   = SecondayLabelView(textAligment: .center, fontSize: 12)
    
    private var textStack     = UIStackView()
    private var valueStack     = UIStackView()
    private var mainStack     = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with ticker: StockEntity) {
        tickerLabel.text = ticker.symbol
        nameLabel.text = ticker.longName
        priceLabel.text = String(format: "R$ %.2f", ticker.quote.lastPrice)

        let change = ticker.quote.changePercent
        changeBadge.text = String(format: "%@%.2f%%", change >= 0 ? "+" : "", change)

        let color: UIColor = change >= 0 ? .systemGreen : .systemRed
        changeBadge.textColor = color
        changeBadge.backgroundColor = color.withAlphaComponent(0.15)
        
        logoImageView.setImage(for: ticker.logoUrl)
    }
    
    
    private func configureTableCellView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
    }

    private func setupViews() {
        
        configureTableCellView()
        configureChangeTextView()
        configureTextStackView()
        configureValueStackView()
        configureMainStackView()

        
        cardView.addSubview(mainStack)
        contentView.addSubview(cardView)
        
        setupLayoutConstrains()
    }
    
    func configureChangeTextView() {
        changeBadge.layer.cornerRadius = 8
        changeBadge.layer.cornerCurve = .continuous
        changeBadge.clipsToBounds = true
    }
    
    func configureTextStackView() {
        textStack           = UIStackView(arrangedSubviews: [tickerLabel, nameLabel])
        
        textStack.axis      = .vertical
        textStack.spacing   = 2
    }
    
    func configureValueStackView() {
        valueStack              = UIStackView(arrangedSubviews: [priceLabel, changeBadge])
        valueStack.axis         = .vertical
        valueStack.spacing      = 4
        valueStack.alignment    = .trailing
    }
    
    
    func configureMainStackView() {
        mainStack = UIStackView(arrangedSubviews: [logoImageView, textStack, valueStack])
        mainStack.axis = .horizontal
        mainStack.alignment = .center
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setupLayoutConstrains() {
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            logoImageView.widthAnchor.constraint(equalToConstant: 40),
            logoImageView.heightAnchor.constraint(equalToConstant: 40),

            mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            changeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            changeBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
}
