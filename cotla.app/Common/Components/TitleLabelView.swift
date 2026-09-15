//
//  TitleLabel.swift
//  cotla.app
//
//  Created by Luiz Felipe on 14/09/26.
//

import UIKit

class TitleLabelView: UILabel {

    override init(frame: CGRect) {
        super.init(frame: .zero)
        
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(textAligment: NSTextAlignment, fontSize: CGFloat) {
        super.init(frame: .zero)
        
        translatesAutoresizingMaskIntoConstraints = false
        self.textAlignment                        = textAligment
        self.font                                 = UIFont.systemFont(ofSize: fontSize, weight: .bold)
    }
    
    
    private func configure() {
        textColor                 = .label
        adjustsFontSizeToFitWidth = true
        minimumScaleFactor        = 0.9
        lineBreakMode             = .byTruncatingTail
    }
}
