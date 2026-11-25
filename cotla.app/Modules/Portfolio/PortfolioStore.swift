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

    /// Tira as cotas e guarda a venda; o preço médio não muda. Zerada, a posição fica como encerrada
    /// (uma compra nova do mesmo ativo volta a abri-la, com PM só das compras novas).
    static func sell(_ sale: PositionEntity.Sale, of position: PositionEntity) {
        save(all().map { current in
            guard current.symbol == position.symbol && current.kind == position.kind else { return current }

            var updated       = current
            let remaining     = current.quantity - sale.quantity
            updated.quantity  = remaining < 1e-9 ? 0 : remaining
            updated.sales     = (current.sales ?? []) + [sale]
            return updated
        })
    }

    /// Desfaz uma venda registrada por engano: as cotas voltam com o mesmo preço médio.
    /// Só vale sem compra depois dela, porque uma compra posterior já recalculou o PM.
    static func undoSale(at index: Int, of position: PositionEntity) {
        save(all().map { current in
            guard current.symbol == position.symbol && current.kind == position.kind,
                  var sales = current.sales, sales.indices.contains(index) else { return current }

            var updated      = current
            updated.quantity = current.quantity + sales.remove(at: index).quantity
            updated.sales    = sales
            return updated
        })
    }

    static func remove(_ position: PositionEntity) {
        save(all().filter { !($0.symbol == position.symbol && $0.kind == position.kind) })
    }
}
