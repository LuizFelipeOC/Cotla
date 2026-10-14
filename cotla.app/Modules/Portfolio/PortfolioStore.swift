//
//  PortfolioStore.swift
//  cotla.app
//

import Foundation

/// Carteira local: tudo fica no aparelho, nada vai para a brapi.
enum PortfolioStore {
    private static let key = "portfolio"

    static func all() -> [PositionEntity] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PositionEntity].self, from: data)) ?? []
    }

    static func save(_ positions: [PositionEntity]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(positions), forKey: key)
    }

    /// Adicionar um ativo que já está na carteira soma ao que existe, recalculando o preço médio.
    static func add(_ position: PositionEntity) {
        var positions = all()

        if let index = positions.firstIndex(where: { $0.symbol == position.symbol && $0.kind == position.kind }) {
            let existing = positions[index]
            let quantity = existing.quantity + position.quantity

            positions[index].averagePrice = (existing.invested + position.invested) / quantity
            positions[index].quantity     = quantity
            positions[index].currentPrice = position.currentPrice ?? existing.currentPrice
            positions[index].logoUrl      = position.logoUrl ?? existing.logoUrl
            positions[index].lots         = (existing.lots ?? []) + (position.lots ?? [])
        } else {
            positions.append(position)
        }

        save(positions)
    }

    static func remove(_ position: PositionEntity) {
        save(all().filter { !($0.symbol == position.symbol && $0.kind == position.kind) })
    }
}
