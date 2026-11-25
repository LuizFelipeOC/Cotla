//
//  PositionEntity.swift
//  cotla.app
//

import Foundation

nonisolated enum AssetKind: String, Codable, CaseIterable {
    case stock, fii, etf, crypto, treasury, fixedIncome

    var title: String {
        switch self {
        case .stock:  return "Ações"
        case .fii:    return "FIIs"
        case .etf:    return "ETFs"
        case .crypto: return "Cripto"
        case .treasury: return "Tesouro"
        case .fixedIncome: return "Renda Fixa"
        }
    }

    /// Negociados na B3: têm cotação no /tickers, fechamento por data e proventos.
    var isListedOnB3: Bool {
        self == .stock || self == .fii || self == .etf
    }

    /// Renda fixa privada não tem cotação pública: entra só pela carteira, não pela busca.
    static var quotable: [AssetKind] { allCases.filter { $0 != .fixedIncome } }

    /// Tesouro e renda fixa saem por resgate, com IOF e IR regressivos, não pela venda com preço médio.
    var isSellable: Bool { self != .treasury && self != .fixedIncome }
}

nonisolated struct PositionEntity: Codable {
    let symbol: String
    let kind: AssetKind
    var quantity: Double
    var averagePrice: Double
    var currentPrice: Double?
    var logoUrl: String?
    /// Nome para exibir quando o código não é legível (ex.: "Tesouro Selic 2031").
    var name: String?
    /// Cada compra com a data, para saber quantas cotas havia em cada data com.
    var lots: [Lot]?
    /// Vendas registradas. Zerada a quantidade, a posição continua guardada como encerrada.
    var sales: [Sale]?
    /// Proventos já pagos desde a compra (valor bruto), recalculado ao atualizar a carteira.
    var dividendsReceived: Double?
    /// CDB, LCI etc.: quantidade 1, preço médio = valor aplicado e `currentPrice` = valor líquido de IOF e IR.
    var fixedIncome: FixedIncome?

    nonisolated struct Lot: Codable {
        let date: String     // YYYY-MM-DD
        let quantity: Double
        /// Preço por cota com os custos. Compras registradas antes deste campo não têm.
        var price: Double?
    }

    nonisolated struct Sale: Codable {
        let date: String     // YYYY-MM-DD
        let quantity: Double
        /// Por cota, antes dos custos.
        let price: Double
        let fees: Double
        /// Preço médio na data da venda. Vender não muda o PM, mas compras depois mudam.
        let averagePrice: Double

        /// O que entra na conta: custos da venda reduzem o ganho.
        var proceeds: Double { quantity * price - fees }
        /// Ganho de capital pela regra do preço médio: venda líquida − PM × quantidade.
        var profit: Double { proceeds - quantity * averagePrice }
    }

    var invested: Double { quantity * averagePrice }

    var isClosed: Bool { quantity == 0 }

    var realizedProfit: Double { (sales ?? []).reduce(0) { $0 + $1.profit } }

    /// Compras (+) e vendas (−) por data. No mesmo dia, compras vêm antes das vendas.
    var quantityChanges: [Lot] {
        ((lots ?? []) + (sales ?? []).map { Lot(date: $0.date, quantity: -$0.quantity) })
            .sorted { ($0.date, $0.quantity < 0 ? 1 : 0) < ($1.date, $1.quantity < 0 ? 1 : 0) }
    }

    /// Cotas em carteira ao fim de `date` (YYYY-MM-DD).
    func quantity(on date: String) -> Double {
        quantityChanges.filter { $0.date <= date }.reduce(0) { $0 + $1.quantity }
    }

    /// Compras que ainda estão em carteira. Como no preço médio, as cotas são um bolo só:
    /// cada venda tira a mesma proporção de todas as compras anteriores.
    var heldLots: [Lot] {
        var held: [Lot] = []

        for change in quantityChanges {
            if change.quantity > 0 {
                held.append(change)
                continue
            }

            let total = held.reduce(0) { $0 + $1.quantity }
            guard total > 0 else { continue }

            let keep = max(0, 1 + change.quantity / total)
            held = held.map { Lot(date: $0.date, quantity: $0.quantity * keep, price: $0.price) }
        }

        return held.filter { $0.quantity > 1e-9 }
    }

    /// A venda não pode deixar nenhum dia com quantidade negativa, nem antes nem depois dela.
    /// Sem compras datadas (ex.: cripto), vale só a quantidade atual.
    func canSell(_ quantity: Double, on date: String) -> Bool {
        guard quantity > 0 else { return false }
        guard lots?.isEmpty == false else { return quantity <= self.quantity + 1e-9 }

        var running = 0.0
        let changes = (quantityChanges + [Lot(date: date, quantity: -quantity)])
            .sorted { ($0.date, $0.quantity < 0 ? 1 : 0) < ($1.date, $1.quantity < 0 ? 1 : 0) }

        for change in changes {
            running += change.quantity
            if running < -1e-9 { return false }
        }
        return true
    }

    /// Sem cotação, assume o preço médio para não distorcer o total.
    var currentValue: Double { quantity * (currentPrice ?? averagePrice) }

    var resultPercent: Double? {
        guard let currentPrice, averagePrice > 0 else { return nil }
        return (currentPrice / averagePrice - 1) * 100
    }

    /// Cotas com direito ao provento: as que estavam em carteira ao fim da data com (`lastDatePrior`, inclusiva);
    /// sem ela, antes do `exDate`. Quem vende na data com perde o provento. Data com futura conta as cotas atuais.
    func entitledQuantity(for dividend: CashDividendEntity) -> Double {
        let changes = quantityChanges

        if let dataCom = dividend.lastDatePrior?.prefix(10) {
            return max(changes.filter { $0.date <= dataCom }.reduce(0) { $0 + $1.quantity }, 0)
        }
        if let exDate = dividend.exDate?.prefix(10) {
            return max(changes.filter { $0.date < exDate }.reduce(0) { $0 + $1.quantity }, 0)
        }
        return 0
    }

    /// Soma os proventos já pagos (`paymentDate` <= `today`) para as cotas com direito.
    func dividendsReceived(from dividends: [CashDividendEntity], today: String) -> Double {
        dividends.reduce(0) { total, dividend in
            guard let paid = dividend.paymentDate?.prefix(10), paid <= today else { return total }
            return total + entitledQuantity(for: dividend) * dividend.rate
        }
    }

    /// Proventos anunciados com pagamento depois de `today`, já multiplicados pelas cotas com direito.
    func upcomingDividends(from dividends: [CashDividendEntity], today: String) -> [UpcomingDividend] {
        dividends.compactMap { dividend in
            guard let payment = dividend.paymentDate?.prefix(10), payment > today else { return nil }

            let quantity = entitledQuantity(for: dividend)
            guard quantity > 0 else { return nil }

            return UpcomingDividend(symbol: symbol, label: dividend.label ?? "Provento",
                                    dataCom: (dividend.lastDatePrior ?? dividend.exDate).map { String($0.prefix(10)) },
                                    paymentDate: String(payment), amount: quantity * dividend.rate)
        }
    }
}

nonisolated struct CryptoResponse: Decodable {
    let coins: [CryptoEntity]
}

nonisolated struct CryptoEntity: Decodable {
    let coin: String
    let coinName: String?
    let coinImageUrl: String?
    let regularMarketPrice: Double
    let regularMarketChangePercent: Double?
    let regularMarketVolume: Double?
}

nonisolated struct CryptoAvailableResponse: Decodable {
    let coins: [String]
}

nonisolated struct TreasuryListResponse: Decodable {
    let results: [TreasuryEntity]
}

nonisolated struct TreasuryEntity: Decodable {
    let symbol: String
    let bondType: String
    let indexer: String
    let maturityDate: String?
    let buyRate: Double?
    let buyPrice: Double?
    let sellPrice: Double?

    /// "Tesouro Selic 2031"
    var displayName: String {
        guard let year = maturityDate?.prefix(4) else { return bondType }
        return "\(bondType) \(year)"
    }

    /// O sentido da taxa muda por indexador: no Selic é spread, no prefixado é a taxa total.
    var rateDescription: String {
        guard let buyRate else { return "Indisponível para compra" }

        let rate = (buyRate / 100).formatted(.percent.precision(.fractionLength(2)).locale(Locale(identifier: "pt_BR")))

        switch indexer {
        case "selic": return "Selic + \(rate) a.a."
        case "ipca":  return "IPCA + \(rate) a.a."
        case "igpm":  return "IGP-M + \(rate) a.a."
        default:      return "\(rate) a.a."
        }
    }
}

nonisolated struct TreasuryHistoryResponse: Decodable {
    let results: [TreasuryHistorySeries]
}

nonisolated struct TreasuryHistorySeries: Decodable {
    let history: [TreasuryHistoryEntry]
}

nonisolated struct TreasuryHistoryEntry: Decodable {
    let baseDate: String
    let buyPrice: Double?
}

nonisolated struct UpcomingDividend: Identifiable {
    let symbol: String
    let label: String
    let dataCom: String?      // YYYY-MM-DD
    let paymentDate: String   // YYYY-MM-DD
    let amount: Double

    var id: String { "\(symbol)-\(label)-\(paymentDate)-\(dataCom ?? "")" }
}

/// Um dia da série 12 do Banco Central: CDI diário em % ao dia.
nonisolated struct CdiDayEntity: Decodable {
    let data: String    // DD/MM/YYYY
    let valor: String

    /// Data em YYYY-MM-DD para comparar com as datas das compras.
    var isoDate: String {
        let parts = data.split(separator: "/")
        return parts.count == 3 ? "\(parts[2])-\(parts[1])-\(parts[0])" : data
    }

    var dailyRate: Double { (Double(valor) ?? 0) / 100 }
}

nonisolated enum Cdi {
    /// Fator acumulado do CDI a partir de `date` (inclusive): quem aplica no dia rende a taxa daquele dia.
    static func factor(since date: String, in days: [CdiDayEntity]) -> Double {
        days.filter { $0.isoDate >= date }.reduce(1) { $0 * (1 + $1.dailyRate) }
    }
}

/// Renda fixa privada com as regras de resgate de pessoa física:
/// rende por dia útil (DU/252), IOF regressivo nos primeiros 29 dias corridos sobre o rendimento
/// e IR pela tabela regressiva sobre o rendimento já sem o IOF.
nonisolated struct FixedIncome: Codable {

    enum Product: String, Codable, CaseIterable {
        case cdb, lc, lci, lca, debenture, incentivizedDebenture

        var title: String {
            switch self {
            case .cdb:                   return "CDB"
            case .lc:                    return "LC"
            case .lci:                   return "LCI"
            case .lca:                   return "LCA"
            case .debenture:             return "Debênture"
            case .incentivizedDebenture: return "Debênture incentivada"
            }
        }

        /// LCI, LCA (Lei 11.033/2004) e debênture incentivada (Lei 12.431/2011) são isentas para pessoa física.
        var hasIncomeTax: Bool { self == .cdb || self == .lc || self == .debenture }

        /// Debêntures têm alíquota zero de IOF (Decreto 6.306/2007, art. 32, § 2º).
        var hasIof: Bool { self != .debenture && self != .incentivizedDebenture }
    }

    enum Indexer: String, Codable, CaseIterable {
        case cdiPercent, cdiPlus, prefixed

        var title: String {
            switch self {
            case .cdiPercent: return "Pós · % CDI"
            case .cdiPlus:    return "Pós · CDI +"
            case .prefixed:   return "Prefixado"
            }
        }
    }

    /// Resultado de um resgate hipotético na data do cálculo.
    struct Breakdown: Codable {
        let gross: Double
        let iof: Double
        let incomeTax: Double
        let daysHeld: Int

        var net: Double { gross - iof - incomeTax }

        /// Resgate parcial: bruto, IOF e IR saem na mesma proporção, e a data da aplicação não muda.
        func scaled(by fraction: Double) -> Breakdown {
            Breakdown(gross: gross * fraction, iof: iof * fraction, incomeTax: incomeTax * fraction, daysHeld: daysHeld)
        }
    }

    let product: Product
    let indexer: Indexer
    /// % do CDI (110 = 110%), spread em % a.a. sobre o CDI ou taxa prefixada em % a.a.
    let rate: Double
    /// YYYY-MM-DD. O título rende até aqui e é pago na conta; depois disso o valor não muda.
    let maturity: String?
    /// Resgate a qualquer momento pelo valor na curva. Sem ela, o dinheiro só sai no vencimento.
    let dailyLiquidity: Bool?
    /// Último cálculo de um resgate hoje (ou do pagamento, se já venceu), para mostrar sem refazer a conta.
    var breakdown: Breakdown?
    /// Estimativa no vencimento, enquanto não venceu.
    var maturityBreakdown: Breakdown?

    func isMatured(on day: String) -> Bool {
        maturity.map { $0 <= day } ?? false
    }

    func canRedeem(on day: String) -> Bool {
        dailyLiquidity == true || isMatured(on: day)
    }

    var rateDescription: String {
        let rateText = rate.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "pt_BR")))
        switch indexer {
        case .cdiPercent: return "\(rateText)% do CDI"
        case .cdiPlus:    return "CDI + \(rateText)% a.a."
        case .prefixed:   return "\(rateText)% a.a."
        }
    }

    /// Bruto, IOF, IR e líquido de um resgate, com as alíquotas pelos dias corridos.
    func lines(for breakdown: Breakdown) -> [String] {
        let days    = breakdown.daysHeld
        let percent = { (rate: Double) in rate.formatted(.percent.precision(.fractionLength(0...1)).locale(Locale(identifier: "pt_BR"))) }

        let iof: String
        if !product.hasIof {
            iof = "IOF: não incide"
        } else if days >= 30 {
            iof = "IOF: zero a partir de 30 dias"
        } else {
            iof = "IOF (\(percent(Self.iofRate(daysHeld: days))) do rendimento): −\(breakdown.iof.asCurrency)"
        }

        let tax = product.hasIncomeTax
            ? "IR (\(percent(Self.incomeTaxRate(daysHeld: days)))): −\(breakdown.incomeTax.asCurrency)"
            : "IR: isento"

        return ["Bruto: \(breakdown.gross.asCurrency)", iof, tax, "Líquido: \(breakdown.net.asCurrency)"]
    }

    /// Fator de um dia útil. O CDI diário do BCB já é a taxa do dia; taxas anuais viram diárias por (1 + i)^(1/252).
    func dailyFactor(cdiDailyRate: Double) -> Double {
        switch indexer {
        case .cdiPercent: return 1 + cdiDailyRate * rate / 100
        case .cdiPlus:    return (1 + cdiDailyRate) * pow(1 + rate / 100, 1.0 / 252)
        case .prefixed:   return pow(1 + rate / 100, 1.0 / 252)
        }
    }

    /// Resgate em `day` (YYYY-MM-DD): rende os dias úteis da aplicação (inclusive) até `day` (exclusive)
    /// e desconta IOF e IR pelos dias corridos. Depois do vencimento, vale o que foi pago nele.
    func redemption(invested: Double, appliedOn date: String, on day: String, cdi days: [CdiDayEntity]) -> Breakdown {
        let end   = min(day, maturity ?? day)
        let gross = days.filter { $0.isoDate >= date && $0.isoDate < end }
            .reduce(invested) { $0 * dailyFactor(cdiDailyRate: $1.dailyRate) }

        return breakdown(invested: invested, gross: gross, daysHeld: Self.daysBetween(date, end))
    }

    /// Resgate parcial em `day` de `amount` líquido (o que cai na conta) ou bruto. Devolve o que sai, com IOF e IR
    /// proporcionais, e a fração da aplicação que continua rendendo. nil se o valor passar do saldo.
    func partialRedemption(of amount: Double, isNet: Bool, invested: Double, appliedOn date: String, on day: String,
                           cdi days: [CdiDayEntity]) -> (redeemed: Breakdown, remainingFraction: Double)? {
        let full      = redemption(invested: invested, appliedOn: date, on: day, cdi: days)
        let available = isNet ? full.net : full.gross

        // Meio centavo de folga: o saldo digitado à mão vem arredondado e não deve sobrar resíduo.
        guard amount > 0, available > 0, amount <= available + 0.005 else { return nil }

        let fraction = available - amount < 0.005 ? 1 : amount / available
        return (full.scaled(by: fraction), 1 - fraction)
    }

    /// Valor no vencimento partindo do bruto de `day`: rende os dias úteis que faltam (calendário ANBIMA).
    /// Prefixado é exato; pós-fixado é estimativa, supondo o CDI diário de hoje até o fim.
    func projectedAtMaturity(invested: Double, appliedOn date: String, from day: String, gross: Double,
                             cdiDailyRate: Double) -> Breakdown? {
        guard let maturity, maturity > day else { return nil }

        let remaining = BusinessDays.count(from: day, to: maturity)
        let projected = gross * pow(dailyFactor(cdiDailyRate: cdiDailyRate), Double(remaining))

        return breakdown(invested: invested, gross: projected, daysHeld: Self.daysBetween(date, maturity))
    }

    /// IOF e IR de um resgate com `gross` bruto depois de `daysHeld` dias corridos.
    func breakdown(invested: Double, gross: Double, daysHeld: Int) -> Breakdown {
        let income    = max(gross - invested, 0)
        let iof       = product.hasIof ? income * Self.iofRate(daysHeld: daysHeld) : 0
        let incomeTax = product.hasIncomeTax ? (income - iof) * Self.incomeTaxRate(daysHeld: daysHeld) : 0

        return Breakdown(gross: gross, iof: iof, incomeTax: incomeTax, daysHeld: daysHeld)
    }

    /// Tabela do IOF (Decreto 6.306/2007, anexo): % do rendimento por dia corrido, do 1º ao 29º. Do 30º em diante, zero.
    static let iofTable: [Double] = [96, 93, 90, 86, 83, 80, 76, 73, 70, 66, 63, 60, 56, 53, 50,
                                     46, 43, 40, 36, 33, 30, 26, 23, 20, 16, 13, 10, 6, 3]

    static func iofRate(daysHeld: Int) -> Double {
        (1...29).contains(daysHeld) ? iofTable[daysHeld - 1] / 100 : 0
    }

    /// Tabela regressiva do IR (Lei 11.033/2004, art. 1º), por dias corridos.
    static func incomeTaxRate(daysHeld: Int) -> Double {
        switch daysHeld {
        case ...180: return 0.225
        case ...360: return 0.20
        case ...720: return 0.175
        default:     return 0.15
        }
    }

    /// Dias corridos entre duas datas YYYY-MM-DD.
    static func daysBetween(_ start: String, _ end: String) -> Int {
        let style = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
        guard let from = try? Date(start, strategy: style), let to = try? Date(end, strategy: style) else { return 0 }
        return Int((to.timeIntervalSince(from) / 86_400).rounded())
    }
}

/// Dias úteis do calendário ANBIMA: segunda a sexta, menos feriados nacionais. No passado o app usa os dias
/// publicados do CDI; este calendário serve para contar os dias que ainda faltam até um vencimento.
nonisolated enum BusinessDays {

    private static let style = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    private static let calendar: Calendar = {
        var calendar      = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Dias úteis de `start` (inclusive) até `end` (exclusive), datas YYYY-MM-DD.
    static func count(from start: String, to end: String) -> Int {
        guard var date = try? Date(start, strategy: style), let last = try? Date(end, strategy: style) else { return 0 }

        var count = 0
        while date < last {
            if isBusinessDay(date) { count += 1 }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? last
        }
        return count
    }

    static func isBusinessDay(_ date: Date) -> Bool {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              parts.weekday != 1, parts.weekday != 7 else { return false }

        // Fixos; Consciência Negra é feriado nacional desde 2024 (Lei 14.759/2023).
        var fixed: [(Int, Int)] = [(1, 1), (4, 21), (5, 1), (9, 7), (10, 12), (11, 2), (11, 15), (12, 25)]
        if year >= 2024 { fixed.append((11, 20)) }
        if fixed.contains(where: { $0 == (month, day) }) { return false }

        // Móveis pela Páscoa: Carnaval (segunda e terça), Sexta-feira Santa e Corpus Christi.
        let easter = easterSunday(year)
        return ![-48, -47, -2, 60].contains { calendar.date(byAdding: .day, value: $0, to: easter) == date }
    }

    /// Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher).
    static func easterSunday(_ year: Int) -> Date {
        let a = year % 19, b = year / 100, c = year % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let n = h + l - 7 * m + 114

        return calendar.date(from: DateComponents(year: year, month: n / 31, day: n % 31 + 1)) ?? .distantPast
    }
}
