//
//  Double+Currency.swift
//  cotla.app
//

import Foundation

extension Double {

    private static let brazilLocale = Locale(identifier: "pt_BR")

    /// Valor em reais com símbolo: "R$ 1.234,56".
    var asCurrency: String {
        formatted(.currency(code: "BRL").locale(Self.brazilLocale))
    }

    /// Valor em reais sem símbolo, com duas casas: "1.234,56".
    var asPrice: String {
        formatted(.number.precision(.fractionLength(2)).locale(Self.brazilLocale))
    }
}
