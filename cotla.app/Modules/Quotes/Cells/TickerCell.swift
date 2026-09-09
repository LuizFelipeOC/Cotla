//
//  TickerCellViewCell.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit
import SDWebImage

class TickerCell: UITableViewCell {

    static let reuseIdentifier = "TickerCell"

    private let cardView = UIView()
    private let logoImageView = UIImageView()
    private let tickerLabel = UILabel()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let changeBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        logoImageView.sd_cancelCurrentImageLoad()
        logoImageView.image = nil
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 18
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.layer.cornerRadius = 10
        logoImageView.clipsToBounds = true
        logoImageView.backgroundColor = .tertiarySystemGroupedBackground
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        tickerLabel.font = .systemFont(ofSize: 16, weight: .bold)

        nameLabel.font = .systemFont(ofSize: 12, weight: .regular)
        nameLabel.textColor = .secondaryLabel
        nameLabel.numberOfLines = 1

        priceLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        priceLabel.textAlignment = .right

        changeBadge.font = .systemFont(ofSize: 12, weight: .bold)
        changeBadge.textAlignment = .center
        changeBadge.layer.cornerRadius = 8
        changeBadge.layer.cornerCurve = .continuous
        changeBadge.clipsToBounds = true

        let textStack = UIStackView(arrangedSubviews: [tickerLabel, nameLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let valueStack = UIStackView(arrangedSubviews: [priceLabel, changeBadge])
        valueStack.axis = .vertical
        valueStack.spacing = 4
        valueStack.alignment = .trailing

        let mainStack = UIStackView(arrangedSubviews: [logoImageView, textStack, valueStack])
        mainStack.axis = .horizontal
        mainStack.alignment = .center
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(mainStack)

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

    func configure(with ticker: StockEntity) {
        tickerLabel.text = ticker.symbol
        nameLabel.text = ticker.longName
        priceLabel.text = String(format: "R$ %.2f", ticker.quote.lastPrice)

        let change = ticker.quote.changePercent
        changeBadge.text = String(format: "%@%.2f%%", change >= 0 ? "+" : "", change)

        let color: UIColor = change >= 0 ? .systemGreen : .systemRed
        changeBadge.textColor = color
        changeBadge.backgroundColor = color.withAlphaComponent(0.15)

        logoImageView.sd_setImage(
            with: URL(string: ticker.logoUrl),
            placeholderImage: UIImage(systemName: "chart.bar.fill")
        )
    }
}
