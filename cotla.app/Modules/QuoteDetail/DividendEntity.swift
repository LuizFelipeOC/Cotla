//
//  DividendEntity.swift
//  cotla.app
//

import Foundation

nonisolated class DividendsResponse: Decodable {
    let results: [DividendsResultEntity]
}

/// A brapi tem um endpoint separado para dividendos de FIIs, com formato próprio
/// (sem o wrapper `results[].data`).
nonisolated class FiiDividendsResponse: Decodable {
    let dividends: [CashDividendEntity]
}

nonisolated class DividendsResultEntity: Decodable {
    let symbol: String
    let data: DividendsDataEntity
}

nonisolated class DividendsDataEntity: Decodable {
    let cashDividends: [CashDividendEntity]
}

nonisolated class CashDividendEntity: Decodable {
    let rate: Double
    let label: String?
    let paymentDate: String?
    let exDate: String?
    /// Data com: último dia em que quem tem a cota recebe o provento.
    let lastDatePrior: String?
}
