//
//  PerformanceViewController.swift
//  cotla.app
//

import UIKit

/// Carteira x CDI e proventos a receber.
class PerformanceViewController: UIViewController {

    private static let brazilLocale = Locale(identifier: "pt_BR")
    private static let brandGreen   = UIColor(named: "BrandGreen") ?? .systemGreen
    private static let isoDay       = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
    /// O gráfico formata as datas no fuso de Brasília; os dias do CDI precisam estar nele.
    private static let saoPauloDay  = Date.ISO8601FormatStyle(timeZone: TimeZone(identifier: "America/Sao_Paulo") ?? .current)
        .year().month().day()

    private var loadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        load()
    }

    private func configure() {
        title                                = "Desempenho"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor                 = .systemBackground

        cdiCard.addSubview(cdiStack)
        dividendsCard.addSubview(dividendsStack)

        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            cdiStack.topAnchor.constraint(equalTo: cdiCard.topAnchor, constant: 16),
            cdiStack.bottomAnchor.constraint(equalTo: cdiCard.bottomAnchor, constant: -16),
            cdiStack.leadingAnchor.constraint(equalTo: cdiCard.leadingAnchor, constant: 16),
            cdiStack.trailingAnchor.constraint(equalTo: cdiCard.trailingAnchor, constant: -16),

            chartView.heightAnchor.constraint(equalToConstant: 180),

            dividendsStack.topAnchor.constraint(equalTo: dividendsCard.topAnchor, constant: 16),
            dividendsStack.bottomAnchor.constraint(equalTo: dividendsCard.bottomAnchor, constant: -16),
            dividendsStack.leadingAnchor.constraint(equalTo: dividendsCard.leadingAnchor, constant: 16),
            dividendsStack.trailingAnchor.constraint(equalTo: dividendsCard.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - Views

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = UIColor(named: "BrandGreen")
        control.addTarget(self, action: #selector(load), for: .valueChanged)
        return control
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView            = UIScrollView()
        scrollView.refreshControl = refreshControl
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var contentStack: UIStackView = {
        let cdiFooter       = makeFootnote("Cada compra é comparada com o mesmo valor aplicado no CDI desde a data da compra. "
                                           + "No gráfico, CDI, Ibovespa e IFIX acumulam desde a primeira compra; o IFIX vem do XFIX11, "
                                           + "ETF que replica o índice. Fontes: Banco Central e brapi.")
        let dividendsHeader = makeSectionTitle("Proventos a receber")

        let stack     = UIStackView(arrangedSubviews: [makeSectionTitle("Carteira x CDI e índices"), cdiCard, cdiFooter,
                                                       dividendsHeader, dividendsCard, dividendsFootnote])
        stack.axis    = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(28, after: cdiFooter)

        return stack
    }()

    // CDI

    private let cdiCard = CardView()

    private let portfolioMetric = MetricView(title: "Sua carteira")
    private let cdiMetric       = MetricView(title: "No CDI")

    private let percentOfCdiLabel: UILabel = {
        let label  = SecondayLabelView(textAligment: .left, fontSize: 15)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }()

    private let chartView: PriceChartView = {
        let chart = PriceChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.valueFormatter = { value in
            (value / 100).formatted(.percent.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR")))
        }
        return chart
    }()

    private let cdiCaptionLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .left, fontSize: 13)
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let cdiStatusLabel: UILabel = {
        let label           = SecondayLabelView(textAligment: .left, fontSize: 15)
        label.text          = "Carregando CDI…"
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var cdiStack: UIStackView = {
        let metrics          = UIStackView(arrangedSubviews: [portfolioMetric, cdiMetric])
        metrics.axis         = .horizontal
        metrics.distribution = .fillEqually

        let stack     = UIStackView(arrangedSubviews: [cdiStatusLabel, metrics, percentOfCdiLabel, chartView, cdiCaptionLabel])
        stack.axis    = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        metrics.isHidden           = true
        percentOfCdiLabel.isHidden = true
        chartView.isHidden         = true
        cdiCaptionLabel.isHidden   = true

        return stack
    }()

    // Proventos

    private let dividendsCard = CardView()

    private let dividendsStack: UIStackView = {
        let stack     = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var dividendsFootnote = makeFootnote("Valores brutos, pelas cotas com direito na data com.")

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label  = TitleLabelView(textAligment: .left, fontSize: 20)
        label.text = text
        return label
    }

    private func makeFootnote(_ text: String) -> UILabel {
        let label           = SecondayLabelView(textAligment: .left, fontSize: 12)
        label.text          = text
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    // MARK: - Carregamento

    @objc private func load() {
        loadTask?.cancel()
        loadTask = Task {
            let positions = PortfolioStore.all().filter { $0.lots?.isEmpty == false }
            let today     = Self.isoDay.format(Date())

            showDividendsMessage("Carregando proventos…")

            await loadCdi(positions: positions, today: today)
            await loadUpcoming(positions: positions, today: today)

            refreshControl.endRefreshing()
        }
    }

    private func loadCdi(positions: [PositionEntity], today: String) async {
        // Sem compras com data, mostra os últimos 12 meses.
        let firstDate = positions.flatMap { $0.lots ?? [] }.map(\.date).min()
            ?? Self.isoDay.format(Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date())

        let days: [CdiDayEntity]
        do {
            days = try await ApiService.shared.getCdi(startDate: Self.brazilianDate(firstDate),
                                                     endDate: Self.brazilianDate(today))
        } catch {
            return showCdiMessage("Não foi possível carregar o CDI do Banco Central. Puxe para tentar de novo.")
        }

        var accumulated = 1.0
        let points = days.compactMap { day -> PriceChartView.Point? in
            accumulated *= 1 + day.dailyRate
            guard let date = try? Date(day.isoDate, strategy: Self.saoPauloDay) else { return nil }
            return PriceChartView.Point(date: date, price: (accumulated - 1) * 100)
        }

        guard let first = points.first, let last = points.last else {
            return showCdiMessage("Ainda não há CDI publicado para o período.")
        }

        cdiStatusLabel.isHidden  = true
        chartView.isHidden       = false
        cdiCaptionLabel.isHidden = false
        chartView.primaryLabel   = nil
        chartView.setPoints(points, animated: true)
        cdiCaptionLabel.text = "CDI acumulado desde \(first.date.formatted(.dateTime.day().month().year().locale(Self.brazilLocale))): \(Self.percentText(last.price))"

        // Compara o que está em carteira: cada compra ainda mantida rende o CDI desde a própria data.
        // Posições encerradas ficam fora dos dois lados (o lucro delas é o realizado da carteira).
        let invested = positions.reduce(0) { $0 + $1.invested }
        guard invested > 0 else { return }

        let cdiValue = positions.flatMap { position in
            position.heldLots.map { $0.quantity * position.averagePrice * Cdi.factor(since: $0.date, in: days) }
        }.reduce(0, +)
        let portfolioValue = positions.reduce(0) { $0 + $1.currentValue + ($1.isClosed ? 0 : $1.dividendsReceived ?? 0) }

        let portfolioPercent = (portfolioValue / invested - 1) * 100
        let cdiPercent       = (cdiValue / invested - 1) * 100

        portfolioMetric.superview?.isHidden = false
        portfolioMetric.set(percent: portfolioPercent, value: portfolioValue)
        cdiMetric.set(percent: cdiPercent, value: cdiValue)

        percentOfCdiLabel.isHidden = cdiPercent <= 0.01
        if cdiPercent > 0.01 {
            percentOfCdiLabel.text      = "\(Int((portfolioPercent / cdiPercent * 100).rounded()))% do CDI"
            percentOfCdiLabel.textColor = portfolioPercent >= cdiPercent ? UIColor(named: "BrandGreen") : .systemRed
        }

        // Linha da carteira por dia, para comparar a trajetória com o CDI no mesmo gráfico.
        let curve = await portfolioCurve(positions: positions, days: days, startDate: firstDate, endDate: today)
        guard curve.count == points.count else { return }

        // Índices no mesmo período e nos mesmos dias; um índice que falhar só fica de fora.
        var comparisons = [PriceChartView.Comparison(label: "CDI", points: points, color: .secondaryLabel)]
        for benchmark in Self.benchmarks {
            let series = await Self.indexCurve(symbol: benchmark.symbol, days: days, startDate: firstDate, endDate: today)
            if series.count == points.count {
                comparisons.append(.init(label: benchmark.label, points: series, color: benchmark.color))
            }
        }

        let curveColor = (curve.last?.price ?? 0) >= (curve.first?.price ?? 0) ? Self.brandGreen : .systemRed
        chartView.primaryLabel = "Carteira"
        chartView.setPoints(curve, animated: true)
        chartView.setComparisons(comparisons)
        cdiCaptionLabel.attributedText = Self.legendText(portfolioColor: curveColor, portfolioPercent: curve.last?.price ?? 0,
                                                         comparisons: comparisons)
    }

    /// Ibovespa direto (^BVSP). A brapi não tem o IFIX, então ele vem do XFIX11, ETF que replica o índice.
    private static let benchmarks: [(label: String, symbol: String, color: UIColor)] = [
        ("Ibovespa", "^BVSP", .systemIndigo),
        ("IFIX", "XFIX11", .systemOrange)
    ]

    /// Variação acumulada desde o primeiro dia do gráfico, nos mesmos dias do CDI. Vazio se a brapi não responder.
    private static func indexCurve(symbol: String, days: [CdiDayEntity],
                                   startDate: String, endDate: String) async -> [PriceChartView.Point] {
        guard let prices = try? await ApiService.shared.getHistorical(symbol: symbol, startDate: startDate, endDate: endDate)
            .results.first?.data.historicalDataPrice else { return [] }

        let closes = closeByDay(prices, days: days)
        guard let base = days.lazy.compactMap({ closes[$0.isoDate] }).first else { return [] }

        // Antes do primeiro pregão com cotação, fica em 0%.
        return days.compactMap { day in
            guard let date = try? Date(day.isoDate, strategy: saoPauloDay) else { return nil }
            return PriceChartView.Point(date: date, price: ((closes[day.isoDate] ?? base) / base - 1) * 100)
        }
    }

    /// Rentabilidade em cada dia do CDI: valor de mercado das cotas em carteira naquele dia (compras menos vendas,
    /// pelas cotações históricas) sobre o custo delas pelo preço médio. Renda fixa entra pelo líquido de um resgate no dia.
    /// ponytail: sem cotação histórica (cripto/tesouro, ou falha de rede), assume o preço médio no período todo;
    /// o custo usa o PM atual, então dias antes de uma compra que mudou o PM ficam aproximados.
    private func portfolioCurve(positions: [PositionEntity], days: [CdiDayEntity],
                                startDate: String, endDate: String) async -> [PriceChartView.Point] {
        var pricesBySymbol: [String: [String: Double]] = [:]

        for position in positions where position.kind.isListedOnB3 {
            let prices = try? await ApiService.shared.getHistorical(symbol: position.symbol, startDate: startDate, endDate: endDate)
                .results.first?.data.historicalDataPrice
            pricesBySymbol[position.symbol] = Self.closeByDay(prices ?? [], days: days)
        }

        // Quantidade 1: o "preço" do dia é o próprio valor líquido da aplicação.
        for position in positions {
            guard let fixedIncome = position.fixedIncome, let applied = position.lots?.first?.date else { continue }
            pricesBySymbol[position.symbol] = Dictionary(days.filter { $0.isoDate >= applied }.map { day in
                (day.isoDate, fixedIncome.redemption(invested: position.invested, appliedOn: applied, on: day.isoDate, cdi: days).net)
            }, uniquingKeysWith: { $1 })
        }

        return days.compactMap { day -> PriceChartView.Point? in
            guard let date = try? Date(day.isoDate, strategy: Self.saoPauloDay) else { return nil }

            var marketValue = 0.0
            var cost        = 0.0

            for position in positions {
                let held = position.quantity(on: day.isoDate)
                guard held > 0 else { continue }

                marketValue += held * (pricesBySymbol[position.symbol]?[day.isoDate] ?? position.averagePrice)
                cost        += held * position.averagePrice
            }

            return PriceChartView.Point(date: date, price: cost > 0 ? (marketValue / cost - 1) * 100 : 0)
        }
    }

    /// Fechamento mais recente até cada dia do CDI (fins de semana/feriados repetem o último pregão).
    private static func closeByDay(_ prices: [HistoricalPriceEntity], days: [CdiDayEntity]) -> [String: Double] {
        let closes = prices.compactMap { price -> (date: String, close: Double)? in
            guard let close = price.close else { return nil }
            return (saoPauloDay.format(Date(timeIntervalSince1970: price.date)), close)
        }.sorted { $0.date < $1.date }

        var result: [String: Double] = [:]
        var cursor = 0
        var lastClose: Double?

        for day in days {
            while cursor < closes.count, closes[cursor].date <= day.isoDate {
                lastClose = closes[cursor].close
                cursor += 1
            }
            if let lastClose { result[day.isoDate] = lastClose }
        }

        return result
    }

    /// "● Carteira +12,30%   ● CDI +8,10%   ● Ibovespa +5,20%   ● IFIX +2,00%", com a cor de cada linha.
    private static func legendText(portfolioColor: UIColor, portfolioPercent: Double,
                                   comparisons: [PriceChartView.Comparison]) -> NSAttributedString {
        let font  = UIFont.systemFont(ofSize: 12)
        let items = [(label: "Carteira", color: portfolioColor, percent: portfolioPercent)]
            + comparisons.map { (label: $0.label, color: $0.color, percent: $0.points.last?.price ?? 0) }

        let text = NSMutableAttributedString()
        for (index, item) in items.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(string: "   ", attributes: [.font: font]))
            }
            text.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: item.color, .font: font]))
            text.append(NSAttributedString(string: "\(item.label) \(percentText(item.percent))",
                                           attributes: [.foregroundColor: UIColor.secondaryLabel, .font: font]))
        }
        return text
    }

    private func showCdiMessage(_ message: String) {
        cdiStatusLabel.text     = message
        cdiStatusLabel.isHidden = false
        chartView.isHidden      = true
        cdiCaptionLabel.isHidden = true
        percentOfCdiLabel.isHidden = true
        portfolioMetric.superview?.isHidden = true
    }

    // ponytail: uma requisição de proventos por ativo em sequência, como na atualização da carteira
    private func loadUpcoming(positions: [PositionEntity], today: String) async {
        var upcoming: [UpcomingDividend] = []

        for position in positions where position.kind.isListedOnB3 {
            let dividends = position.kind == .fii
                ? try? await ApiService.shared.getFiiDividends(symbol: position.symbol).dividends
                : try? await ApiService.shared.getDividends(symbol: position.symbol).results.first?.data.cashDividends

            upcoming += position.upcomingDividends(from: dividends ?? [], today: today)
        }

        guard !upcoming.isEmpty else {
            return showDividendsMessage("Nenhum provento anunciado para os seus ativos.")
        }

        dividendsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        dividendsStack.addArrangedSubview(makeTotalRow(upcoming.reduce(0) { $0 + $1.amount }))
        upcoming.sorted { $0.paymentDate < $1.paymentDate }.forEach { dividendsStack.addArrangedSubview(makeDividendRow($0)) }
        dividendsFootnote.isHidden = false
    }

    private func showDividendsMessage(_ message: String) {
        dividendsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let label           = SecondayLabelView(textAligment: .left, fontSize: 15)
        label.text          = message
        label.textColor     = .secondaryLabel
        label.numberOfLines = 0

        dividendsStack.addArrangedSubview(label)
        dividendsFootnote.isHidden = true
    }

    private func makeTotalRow(_ total: Double) -> UIView {
        let title  = TitleLabelView(textAligment: .left, fontSize: 15)
        title.text = "Total"

        let value       = TitleLabelView(textAligment: .right, fontSize: 15)
        value.text      = total.asCurrency
        value.textColor = UIColor(named: "BrandGreen")

        return UIStackView(arrangedSubviews: [title, value])
    }

    private func makeDividendRow(_ dividend: UpcomingDividend) -> UIView {
        let title       = SecondayLabelView(textAligment: .left, fontSize: 15)
        title.text      = "\(dividend.symbol) · \(dividend.label.capitalized)"
        title.font      = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .label

        let payment         = "Pagamento \(Self.brazilianDate(dividend.paymentDate))"
        let dates           = SecondayLabelView(textAligment: .left, fontSize: 13)
        dates.text          = dividend.dataCom.map { "Data com \(Self.brazilianDate($0)) · \(payment)" } ?? payment
        dates.textColor     = .secondaryLabel
        dates.numberOfLines = 0

        let amount       = SecondayLabelView(textAligment: .right, fontSize: 15)
        amount.text      = dividend.amount.asCurrency
        amount.font      = .systemFont(ofSize: 15, weight: .semibold)
        amount.textColor = .label
        amount.setContentCompressionResistancePriority(.required, for: .horizontal)

        let texts     = UIStackView(arrangedSubviews: [title, dates])
        texts.axis    = .vertical
        texts.spacing = 3

        let row       = UIStackView(arrangedSubviews: [texts, amount])
        row.alignment = .center
        row.spacing   = 12
        return row
    }

    /// "2026-12-21" → "21/12/2026"
    private static func brazilianDate(_ iso: String) -> String {
        iso.split(separator: "-").reversed().joined(separator: "/")
    }

    fileprivate static func percentText(_ percent: Double) -> String {
        (percent >= 0 ? "+" : "") + (percent / 100).formatted(.percent.precision(.fractionLength(2)).locale(brazilLocale))
    }
}

/// Título, % em destaque e valor em R$ ("Sua carteira" / "No CDI").
private final class MetricView: UIStackView {

    private let percentLabel = TitleLabelView(textAligment: .left, fontSize: 20)
    private let valueLabel   = SecondayLabelView(textAligment: .left, fontSize: 13)

    init(title: String) {
        super.init(frame: .zero)

        let titleLabel       = SecondayLabelView(textAligment: .left, fontSize: 13)
        titleLabel.text      = title
        titleLabel.textColor = .secondaryLabel
        valueLabel.textColor = .secondaryLabel

        [titleLabel, percentLabel, valueLabel].forEach(addArrangedSubview)
        axis    = .vertical
        spacing = 2
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(percent: Double, value: Double) {
        percentLabel.text      = PerformanceViewController.percentText(percent)
        percentLabel.textColor = percent >= 0 ? UIColor(named: "BrandGreen") : .systemRed
        valueLabel.text        = value.asCurrency
    }
}
