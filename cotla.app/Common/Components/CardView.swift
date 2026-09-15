//
//  CardView.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit

class CardView: UIView {

    let cornerRadius: CGFloat       = 18
    let shadowOpacity: Float        = 0.08
    let shadowRadius: CGFloat       = 8
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureCard()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func  configureCard() {
        backgroundColor  = .secondarySystemBackground
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: 4)
        
        translatesAutoresizingMaskIntoConstraints = false
    }
}
