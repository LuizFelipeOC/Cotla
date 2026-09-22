//
//  QuoteDetailInteractor.swift
//  cotla.app
//

import Foundation

protocol QuoteDetailInteractorProtocol: AnyObject {
    func getCurrentMonthHistorical(symbol: String)
    func getDividends(symbol: String, isFii: Bool)
}

protocol QuoteDetailInteractorOutputProtocol: AnyObject {
    func onHistoricalSuccess(prices: [HistoricalPriceEntity])
    func onHistoricalError(error: Error)
    func onDividendsSuccess(dividends: [CashDividendEntity])
    func onDividendsError(error: Error)
}

class QuoteDetailInteractor: QuoteDetailInteractorProtocol {
    weak var presenter: QuoteDetailInteractorOutputProtocol?

    private let apiService: ApiServiceProtocol

    init(apiService: ApiServiceProtocol) {
        self.apiService = apiService
    }

    func getCurrentMonthHistorical(symbol: String) {
        Task {
            do {
                // A brapi não tem um range "mês corrente"; buscamos 1 mês e cortamos no dia 1.
                let response = try await apiService.getHistorical(symbol: symbol, range: "1mo", interval: "1d")
                let prices   = response.results.first?.data.historicalDataPrice ?? []
                let start    = Self.startOfCurrentMonth().timeIntervalSince1970

                await MainActor.run {
                    self.presenter?.onHistoricalSuccess(prices: prices.filter { $0.date >= start })
                }
            } catch {
                await MainActor.run {
                    self.presenter?.onHistoricalError(error: error)
                }
            }
        }
    }

    func getDividends(symbol: String, isFii: Bool) {
        Task {
            do {
                // FIIs têm um endpoint próprio na brapi, com formato de resposta diferente
                // e disponível no plano gratuito.
                let dividends: [CashDividendEntity]

                if isFii {
                    dividends = try await apiService.getFiiDividends(symbol: symbol).dividends
                } else {
                    dividends = try await apiService.getDividends(symbol: symbol).results.first?.data.cashDividends ?? []
                }

                await MainActor.run {
                    self.presenter?.onDividendsSuccess(dividends: dividends)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.onDividendsError(error: error)
                }
            }
        }
    }

    private static func startOfCurrentMonth() -> Date {
        var calendar      = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current

        return calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    }
}
