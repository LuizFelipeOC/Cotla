//
//  HistoricalEntity.swift
//  cotla.app
//

import Foundation

nonisolated class HistoricalResponse: Decodable {
    let results: [HistoricalResultEntity]
}

nonisolated class HistoricalResultEntity: Decodable {
    let symbol: String
    let data: HistoricalDataEntity
}

nonisolated class HistoricalDataEntity: Decodable {
    let historicalDataPrice: [HistoricalPriceEntity]
}

nonisolated class HistoricalPriceEntity: Decodable {
    let date: TimeInterval
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double?
    let volume: Double?
}
