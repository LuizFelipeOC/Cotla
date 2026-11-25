//
//  PortfolioStore.swift
//  cotla.app
//

import Foundation

/// Carteira no aparelho, que é de onde as telas leem. Com conta, cada mudança também sobe para a nuvem (`PortfolioSync`).
enum PortfolioStore {
    private static let key         = "portfolio"
    private static let modifiedKey = "portfolioModifiedAt"

    /// A carteira foi trocada pela versão da nuvem: telas abertas precisam recarregar.
    static let didReplace = Notification.Name("PortfolioStore.didReplace")

    /// Hora da última edição feita neste aparelho. nil em carteiras de antes da sincronização.
    static var modifiedAt: Date? {
        UserDefaults.standard.object(forKey: modifiedKey) as? Date
    }

    static func all() -> [PositionEntity] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PositionEntity].self, from: data)) ?? []
    }

    /// `touch: false` para atualizações que não são edição do usuário (cotações, proventos, rendimento),
    /// senão um aparelho desatualizado passaria a parecer o mais recente só por ter aberto o app.
    static func save(_ positions: [PositionEntity], touch: Bool = true) {
        UserDefaults.standard.set(try? JSONEncoder().encode(positions), forKey: key)
        if touch {
            UserDefaults.standard.set(Date(), forKey: modifiedKey)
        }
        PortfolioSync.push()
    }

    /// Versão que veio da nuvem: substitui a local sem contar como edição deste aparelho e sem subir de volta.
    static func replace(with positions: [PositionEntity], modifiedAt: Date?) {
        UserDefaults.standard.set(try? JSONEncoder().encode(positions), forKey: key)
        UserDefaults.standard.set(modifiedAt, forKey: modifiedKey)
        NotificationCenter.default.post(name: didReplace, object: nil)
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
