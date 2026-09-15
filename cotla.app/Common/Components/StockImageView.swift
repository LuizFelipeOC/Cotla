//
//  SockImage.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit
import SDWebImage


class StockImageView: UIImageView {

    var stockImageUrl: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)

        setImage(for: stockImageUrl)
    }

    init() {
        super.init(frame: .zero)
        configureStockImage()
        prepareForReuse()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func prepareForReuse(){
        self.sd_cancelCurrentImageLoad()
        image = nil
    }

    private func configureStockImage() {
        contentMode                                 = .scaleAspectFit
        layer.cornerRadius                          = 10
        clipsToBounds                               = true
        backgroundColor                             = .tertiarySystemGroupedBackground
        translatesAutoresizingMaskIntoConstraints   = false
        layer.cornerRadius                          = 12
        clipsToBounds                               = true
    }

    func setImage(for stockImageUrl: String) {
        sd_setImage(
            with: URL(string: stockImageUrl),
            placeholderImage: UIImage(systemName: "chart.bar.fill")
        )
    }
}
