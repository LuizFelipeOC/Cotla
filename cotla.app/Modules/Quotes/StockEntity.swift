//
//  StockEntity.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation

nonisolated class StockListResponse: Decodable {
    let results: [StockEntity]

    init(results: [StockEntity]) {
        self.results = results
    }
}

nonisolated class StockEntity: Codable {
    let symbol: String
    let name: String
    let longName: String
    let assetType: String
    let subType: String?
    let sector: String?
    let subsector: String?
    let logoUrl: String
    let quote: QuoteEntity

    /// Cripto não vem do /tickers; adapta a cotação do /crypto para reaproveitar lista, célula e detalhe.
    init(crypto: CryptoEntity) {
        symbol    = crypto.coin
        name      = crypto.coinName ?? crypto.coin
        longName  = crypto.coinName ?? crypto.coin
        assetType = "crypto"
        subType   = nil
        sector    = nil
        subsector = nil
        logoUrl   = crypto.coinImageUrl ?? ""
        quote     = QuoteEntity(lastPrice: crypto.regularMarketPrice,
                                changePercent: crypto.regularMarketChangePercent ?? 0,
                                volume: crypto.regularMarketVolume ?? 0)
    }

    /// Tesouro também não vem do /tickers. O preço é o de compra; a taxa vai no lugar do nome longo.
    init(treasury: TreasuryEntity) {
        symbol    = treasury.symbol
        name      = treasury.displayName
        longName  = treasury.rateDescription
        assetType = "treasury"
        subType   = nil
        sector    = nil
        subsector = nil
        logoUrl   = ""
        quote     = QuoteEntity(lastPrice: treasury.buyPrice ?? treasury.sellPrice ?? 0, changePercent: 0, volume: 0)
    }

    var isTreasury: Bool { assetType == "treasury" }

    /// Códigos do Tesouro são longos ("tesouro-selic-01032031"), então mostra o nome.
    var displaySymbol: String { isTreasury ? name : symbol }

    var portfolioKind: AssetKind {
        if isTreasury { return .treasury }
        if assetType == "crypto" { return .crypto }
        return subType == "fii" ? .fii : .stock
    }
}

nonisolated class QuoteEntity: Codable {
    let lastPrice: Double
    let changePercent: Double
    let volume: Double
    let marketCap: Double?

    init(lastPrice: Double, changePercent: Double, volume: Double, marketCap: Double? = nil) {
        self.lastPrice     = lastPrice
        self.changePercent = changePercent
        self.volume        = volume
        self.marketCap     = marketCap
    }
}
