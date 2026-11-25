//
//  AllocationPlan.swift
//  cotla.app
//

import Foundation

/// Metas de alocação por categoria e quanto aportar em cada uma para chegar mais perto delas, só comprando.
nonisolated enum AllocationPlan {

    private static let key = "allocationTargets"

    /// Metas em fração (0,4 = 40%) por categoria. Ficam só no aparelho.
    static func loadTargets() -> [AssetKind: Double] {
        let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        return Dictionary(uniqueKeysWithValues: stored.compactMap { raw, value in AssetKind(rawValue: raw).map { ($0, value) } })
    }

    static func saveTargets(_ targets: [AssetKind: Double]) {
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: targets.map { ($0.key.rawValue, $0.value) }), forKey: key)
    }

    /// Divide `amount` sem vender nada. As categorias que recebem terminam todas na mesma proporção da própria meta
    /// (valor final = meta × nível); as que já passaram desse nível não recebem. Se nenhuma está acima da meta,
    /// isso é exatamente o que falta em cada uma para bater a meta com o aporte.
    static func contributions(current: [AssetKind: Double], targets: [AssetKind: Double],
                              amount: Double) -> [AssetKind: Double] {
        let weights = targets.filter { $0.value > 0 }
        guard amount > 0, let smallest = weights.values.min() else { return [:] }

        func needed(at level: Double) -> [AssetKind: Double] {
            weights.reduce(into: [:]) { result, entry in
                result[entry.key] = max(entry.value * level - (current[entry.key] ?? 0), 0)
            }
        }

        // O total pedido cresce com o nível; neste teto a menor meta sozinha já absorve o aporte inteiro.
        var low  = 0.0
        var high = (current.values.reduce(0, +) + amount) / smallest

        for _ in 0..<100 {
            let mid = (low + high) / 2
            if needed(at: mid).values.reduce(0, +) < amount { low = mid } else { high = mid }
        }

        // Ajuste final para a soma bater o aporte ao centavo.
        let raw = needed(at: high).filter { $0.value > 0 }
        let sum = raw.values.reduce(0, +)
        return sum > 0 ? raw.mapValues { $0 * amount / sum } : [:]
    }
}
