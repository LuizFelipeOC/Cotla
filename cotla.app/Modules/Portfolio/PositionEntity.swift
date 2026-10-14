//
//  PositionEntity.swift
//  cotla.app
//

import Foundation

nonisolated enum AssetKind: String, Codable, CaseIterable {
    case stock, fii, crypto, treasury

    var title: String {
        switch self {
        case .stock:  return "Ações"
        case .fii:    return "FIIs"
        case .crypto: return "Cripto"
        case .treasury: return "Tesouro"
        }
    }
}

nonisolated struct PositionEntity: Codable {
    let symbol: String
    let kind: AssetKind
    var quantity: Double
    var averagePrice: Double
    var currentPrice: Double?
    var logoUrl: String?
    /// Nome para exibir quando o código não é legível (ex.: "Tesouro Selic 2031").
    var name: String?
    /// Cada compra com a data, para saber quantas cotas havia em cada data com.
    var lots: [Lot]?
    /// Proventos já pagos desde a compra (valor bruto), recalculado ao atualizar a carteira.
    var dividendsReceived: Double?

    nonisolated struct Lot: Codable {
        let date: String     // YYYY-MM-DD
        let quantity: Double
    }

    var invested: Double { quantity * averagePrice }

    /// Sem cotação, assume o preço médio para não distorcer o total.
    var currentValue: Double { quantity * (currentPrice ?? averagePrice) }

    var resultPercent: Double? {
        guard let currentPrice, averagePrice > 0 else { return nil }
        return (currentPrice / averagePrice - 1) * 100
    }

    /// Cotas com direito ao provento: as compradas até a data com (`lastDatePrior`, inclusiva);
    /// sem ela, as compradas antes do `exDate`. Data com futura conta todas as cotas atuais.
    func entitledQuantity(for dividend: CashDividendEntity) -> Double {
        let lots = lots ?? []

        if let dataCom = dividend.lastDatePrior?.prefix(10) {
            return lots.filter { $0.date <= dataCom }.reduce(0) { $0 + $1.quantity }
        }
        if let exDate = dividend.exDate?.prefix(10) {
            return lots.filter { $0.date < exDate }.reduce(0) { $0 + $1.quantity }
        }
        return 0
    }

    /// Soma os proventos já pagos (`paymentDate` <= `today`) para as cotas com direito.
    func dividendsReceived(from dividends: [CashDividendEntity], today: String) -> Double {
        dividends.reduce(0) { total, dividend in
            guard let paid = dividend.paymentDate?.prefix(10), paid <= today else { return total }
            return total + entitledQuantity(for: dividend) * dividend.rate
        }
    }

    /// Proventos anunciados com pagamento depois de `today`, já multiplicados pelas cotas com direito.
    func upcomingDividends(from dividends: [CashDividendEntity], today: String) -> [UpcomingDividend] {
        dividends.compactMap { dividend in
            guard let payment = dividend.paymentDate?.prefix(10), payment > today else { return nil }

            let quantity = entitledQuantity(for: dividend)
            guard quantity > 0 else { return nil }

            return UpcomingDividend(symbol: symbol, label: dividend.label ?? "Provento",
                                    dataCom: (dividend.lastDatePrior ?? dividend.exDate).map { String($0.prefix(10)) },
                                    paymentDate: String(payment), amount: quantity * dividend.rate)
        }
    }
}

nonisolated struct CryptoResponse: Decodable {
    let coins: [CryptoEntity]
}

nonisolated struct CryptoEntity: Decodable {
    let coin: String
    let coinName: String?
    let coinImageUrl: String?
    let regularMarketPrice: Double
    let regularMarketChangePercent: Double?
    let regularMarketVolume: Double?
}

nonisolated struct CryptoAvailableResponse: Decodable {
    let coins: [String]
}

nonisolated struct TreasuryListResponse: Decodable {
    let results: [TreasuryEntity]
}

nonisolated struct TreasuryEntity: Decodable {
    let symbol: String
    let bondType: String
    let indexer: String
    let maturityDate: String?
    let buyRate: Double?
    let buyPrice: Double?
    let sellPrice: Double?

    /// "Tesouro Selic 2031"
    var displayName: String {
        guard let year = maturityDate?.prefix(4) else { return bondType }
        return "\(bondType) \(year)"
    }

    /// O sentido da taxa muda por indexador: no Selic é spread, no prefixado é a taxa total.
    var rateDescription: String {
        guard let buyRate else { return "Indisponível para compra" }

        let rate = (buyRate / 100).formatted(.percent.precision(.fractionLength(2)).locale(Locale(identifier: "pt_BR")))

        switch indexer {
        case "selic": return "Selic + \(rate) a.a."
        case "ipca":  return "IPCA + \(rate) a.a."
        case "igpm":  return "IGP-M + \(rate) a.a."
        default:      return "\(rate) a.a."
        }
    }
}

nonisolated struct TreasuryHistoryResponse: Decodable {
    let results: [TreasuryHistorySeries]
}

nonisolated struct TreasuryHistorySeries: Decodable {
    let history: [TreasuryHistoryEntry]
}

nonisolated struct TreasuryHistoryEntry: Decodable {
    let baseDate: String
    let buyPrice: Double?
}

nonisolated struct UpcomingDividend: Identifiable {
    let symbol: String
    let label: String
    let dataCom: String?      // YYYY-MM-DD
    let paymentDate: String   // YYYY-MM-DD
    let amount: Double

    var id: String { "\(symbol)-\(label)-\(paymentDate)-\(dataCom ?? "")" }
}

/// Um dia da série 12 do Banco Central: CDI diário em % ao dia.
nonisolated struct CdiDayEntity: Decodable {
    let data: String    // DD/MM/YYYY
    let valor: String

    /// Data em YYYY-MM-DD para comparar com as datas das compras.
    var isoDate: String {
        let parts = data.split(separator: "/")
        return parts.count == 3 ? "\(parts[2])-\(parts[1])-\(parts[0])" : data
    }

    var dailyRate: Double { (Double(valor) ?? 0) / 100 }
}

nonisolated enum Cdi {
    /// Fator acumulado do CDI a partir de `date` (inclusive): quem aplica no dia rende a taxa daquele dia.
    static func factor(since date: String, in days: [CdiDayEntity]) -> Double {
        days.filter { $0.isoDate >= date }.reduce(1) { $0 * (1 + $1.dailyRate) }
    }
}
