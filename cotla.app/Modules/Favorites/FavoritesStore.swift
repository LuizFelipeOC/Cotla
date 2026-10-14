//
//  FavoritesStore.swift
//  cotla.app
//

import Foundation

/// Guarda um snapshot de cada ativo favoritado, assim a lista abre na hora, mesmo offline.
enum FavoritesStore {
    private static let key = "favorites"

    static func all() -> [StockEntity] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([StockEntity].self, from: data)) ?? []
    }

    static func isFavorite(_ symbol: String) -> Bool {
        all().contains { $0.symbol == symbol }
    }

    static func toggle(_ stock: StockEntity) {
        var favorites = all()

        if let index = favorites.firstIndex(where: { $0.symbol == stock.symbol }) {
            favorites.remove(at: index)
        } else {
            favorites.append(stock)
        }

        save(favorites)
    }

    static func save(_ favorites: [StockEntity]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(favorites), forKey: key)
    }
}
