//
//  SockImage.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit
import SDWebImage


class StockImage: UIImageView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        prepareForReuse()
        configureStockImage()
    }
    
    private func prepareForReuse(){
        self.sd_cancelCurrentImageLoad()
        image = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureStockImage() {
        contentMode = .scaleAspectFit
        layer.cornerRadius = 10
        clipsToBounds = true
        backgroundColor = .tertiarySystemGroupedBackground
        translatesAutoresizingMaskIntoConstraints = false
    }
}
