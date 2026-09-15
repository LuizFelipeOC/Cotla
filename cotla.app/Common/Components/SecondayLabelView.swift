//
//  SecondayLabelView.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit

class SecondayLabelView: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(textAligment: NSTextAlignment, fontSize: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.textAlignment                        = textAligment
        self.font                                 = UIFont.systemFont(ofSize: fontSize, weight: .medium)
    }
    
    
    func configure() {
        textColor = .secondaryLabel
        adjustsFontSizeToFitWidth = true
        minimumScaleFactor        = 0.9
        lineBreakMode             = .byTruncatingTail
    }
}
