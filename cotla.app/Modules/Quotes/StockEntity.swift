//
//  StockEntity.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation

nonisolated class StockListResponse: Decodable {
    let results: [StockEntity]
}

nonisolated class StockEntity: Decodable {
    let symbol: String
    let name: String
    let longName: String
    let assetType: String
    let sector: String?
    let logoUrl: String
    let quote: QuoteEntity
}

nonisolated class QuoteEntity: Decodable {
    let lastPrice: Double
    let changePercent: Double
    let volume: Double
    let marketCap: Double?
}
