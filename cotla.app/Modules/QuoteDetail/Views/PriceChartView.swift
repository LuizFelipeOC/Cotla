//
//  PriceChartView.swift
//  cotla.app
//

import UIKit

final class PriceChartView: UIView {

    struct Point {
        let date: Date
        let price: Double
    }

    private static let brandGreen     = UIColor(named: "BrandGreen") ?? .systemGreen
    private static let brazilLocale   = Locale(identifier: "pt_BR")
    private static let marketTimeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current

    private let topInset: CGFloat    = 48
    private let yAxisWidth: CGFloat  = 48
    private let xAxisHeight: CGFloat = 24

    private var points: [Point] = []
    private var lineColor: UIColor = .systemGreen
    private var priceDomain: ClosedRange<Double> = 0...1
    private var scrubIndex: Int?

    private let axisDateFormatter    = DateFormatter()
    private let tooltipDateFormatter = DateFormatter()

    private let gridLayer      = CAShapeLayer()
    private let areaLayer      = CAGradientLayer()
    private let areaMaskLayer  = CAShapeLayer()
    private let lineLayer      = CAShapeLayer()
    private let endHaloLayer   = CAShapeLayer()
    private let endDotLayer    = CAShapeLayer()
    private let scrubLineLayer = CAShapeLayer()
    private let scrubDotLayer  = CAShapeLayer()

    private let tooltipView       = UIView()
    private let tooltipPriceLabel = UILabel()
    private let tooltipDateLabel  = UILabel()

    private var yAxisLabels: [UILabel] = []
    private var xAxisLabels: [UILabel] = []

    private let feedbackGenerator = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)

        lineColor = Self.brandGreen

        configureFormatters()
        configureLayers()
        configureAxisLabels()
        configureTooltip()
        configureGesture()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (chartView: PriceChartView, _: UITraitCollection) in
            chartView.redraw()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    func setPoints(_ newPoints: [Point], animated: Bool) {
        points = newPoints

        if let first = newPoints.first, let last = newPoints.last {
            lineColor = last.price >= first.price ? Self.brandGreen : .systemRed
        }

        hideScrub()
        redraw()

        if animated, points.count > 1 {
            animateDrawIn()
        }
    }

    // MARK: - Configuração

    private func configureFormatters() {
        for formatter in [axisDateFormatter, tooltipDateFormatter] {
            formatter.locale   = Self.brazilLocale
            formatter.timeZone = Self.marketTimeZone
        }

        axisDateFormatter.dateFormat    = "d MMM"
        tooltipDateFormatter.dateFormat = "d MMM yyyy"
    }

    private func configureLayers() {
        gridLayer.fillColor       = nil
        gridLayer.lineWidth       = 1
        gridLayer.lineDashPattern = [3, 4]

        areaLayer.mask = areaMaskLayer

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2.5
        lineLayer.lineJoin  = .round
        lineLayer.lineCap   = .round

        scrubLineLayer.fillColor       = nil
        scrubLineLayer.lineWidth       = 1
        scrubLineLayer.lineDashPattern = [3, 3]
        scrubLineLayer.isHidden        = true

        scrubDotLayer.lineWidth = 3
        scrubDotLayer.isHidden  = true

        let layers: [CALayer] = [gridLayer, areaLayer, lineLayer, endHaloLayer, endDotLayer, scrubLineLayer, scrubDotLayer]
        layers.forEach { layer.addSublayer($0) }
    }

    private func configureAxisLabels() {
        yAxisLabels = (0..<4).map { _ in makeAxisLabel(alignment: .right) }
        xAxisLabels = [NSTextAlignment.left, .center, .center, .right].map { makeAxisLabel(alignment: $0) }
    }

    private func makeAxisLabel(alignment: NSTextAlignment) -> UILabel {
        let label           = UILabel()
        label.font          = .systemFont(ofSize: 11)
        label.textColor     = .secondaryLabel
        label.textAlignment = alignment
        label.isHidden      = true
        addSubview(label)

        return label
    }

    private func configureTooltip() {
        tooltipView.backgroundColor     = .tertiarySystemBackground
        tooltipView.layer.cornerRadius  = 12
        tooltipView.layer.cornerCurve   = .continuous
        tooltipView.layer.borderWidth   = 1
        tooltipView.layer.shadowColor   = UIColor.black.cgColor
        tooltipView.layer.shadowOpacity = 0.08
        tooltipView.layer.shadowRadius  = 8
        tooltipView.layer.shadowOffset  = CGSize(width: 0, height: 4)
        tooltipView.isHidden            = true

        tooltipPriceLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        tooltipPriceLabel.textColor     = .label
        tooltipPriceLabel.textAlignment = .center

        tooltipDateLabel.font           = .systemFont(ofSize: 11.5)
        tooltipDateLabel.textColor      = .secondaryLabel
        tooltipDateLabel.textAlignment  = .center

        tooltipView.addSubview(tooltipPriceLabel)
        tooltipView.addSubview(tooltipDateLabel)
        addSubview(tooltipView)
    }

    private func configureGesture() {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleScrub(_:)))
        press.minimumPressDuration = 0.15
        addGestureRecognizer(press)
    }

    // MARK: - Desenho

    private var plotRect: CGRect {
        CGRect(
            x: 0,
            y: topInset,
            width: max(bounds.width - yAxisWidth, 0),
            height: max(bounds.height - topInset - xAxisHeight, 0)
        )
    }

    private func position(for index: Int) -> CGPoint {
        let plot     = plotRect
        let progress = points.count > 1 ? CGFloat(index) / CGFloat(points.count - 1) : 0
        let span     = priceDomain.upperBound - priceDomain.lowerBound
        let ratio    = span > 0 ? (points[index].price - priceDomain.lowerBound) / span : 0.5

        return CGPoint(x: plot.minX + plot.width * progress, y: plot.maxY - plot.height * CGFloat(ratio))
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        applyColors()

        let plot = plotRect

        guard points.count > 1, plot.width > 0, plot.height > 0 else {
            [gridLayer, areaMaskLayer, lineLayer, endHaloLayer, endDotLayer].forEach { $0.path = nil }
            (yAxisLabels + xAxisLabels).forEach { $0.isHidden = true }
            return
        }

        updatePriceDomain()
        drawGrid(in: plot)
        drawLine(in: plot)
        drawXAxisLabels(in: plot)

        if let scrubIndex {
            showScrub(at: scrubIndex)
        }
    }

    private func applyColors() {
        let line = lineColor.resolvedColor(with: traitCollection)

        gridLayer.strokeColor         = UIColor.separator.resolvedColor(with: traitCollection).cgColor
        lineLayer.strokeColor         = line.cgColor
        areaLayer.colors              = [line.withAlphaComponent(0.28).cgColor, line.withAlphaComponent(0).cgColor]
        endHaloLayer.fillColor        = line.withAlphaComponent(0.2).cgColor
        endDotLayer.fillColor         = line.cgColor
        scrubLineLayer.strokeColor    = UIColor.label.resolvedColor(with: traitCollection).withAlphaComponent(0.25).cgColor
        scrubDotLayer.fillColor       = line.cgColor
        scrubDotLayer.strokeColor     = UIColor.secondarySystemBackground.resolvedColor(with: traitCollection).cgColor
        tooltipView.layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    }

    private func updatePriceDomain() {
        let prices = points.map(\.price)
        guard var lower = prices.min(), var upper = prices.max() else { return }

        if lower == upper {
            lower -= 1
            upper += 1
        }

        let padding = (upper - lower) * 0.1
        priceDomain = (lower - padding)...(upper + padding)
    }

    private func drawGrid(in plot: CGRect) {
        let path = UIBezierPath()
        let span = priceDomain.upperBound - priceDomain.lowerBound

        for (index, label) in yAxisLabels.enumerated() {
            let ratio = CGFloat(index) / CGFloat(yAxisLabels.count - 1)
            let y     = plot.minY + plot.height * ratio
            let value = priceDomain.upperBound - span * Double(ratio)

            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))

            label.text     = value.asPrice
            label.frame    = CGRect(x: plot.maxX + 4, y: y - 7, width: yAxisWidth - 4, height: 14)
            label.isHidden = false
        }

        gridLayer.path = path.cgPath
    }

    private func drawLine(in plot: CGRect) {
        let line = UIBezierPath()

        for index in points.indices {
            let point = position(for: index)
            if index == 0 {
                line.move(to: point)
            } else {
                line.addLine(to: point)
            }
        }

        lineLayer.path = line.cgPath

        let area = UIBezierPath(cgPath: line.cgPath)
        area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        area.close()

        areaLayer.frame      = bounds
        areaLayer.startPoint = CGPoint(x: 0.5, y: plot.minY / bounds.height)
        areaLayer.endPoint   = CGPoint(x: 0.5, y: plot.maxY / bounds.height)
        areaMaskLayer.frame  = areaLayer.bounds
        areaMaskLayer.path   = area.cgPath

        let last = position(for: points.count - 1)
        endHaloLayer.path = UIBezierPath(ovalIn: CGRect(x: last.x - 9, y: last.y - 9, width: 18, height: 18)).cgPath
        endDotLayer.path  = UIBezierPath(ovalIn: CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8)).cgPath
    }

    private func drawXAxisLabels(in plot: CGRect) {
        let lastIndex      = points.count - 1
        let indices        = [0, lastIndex / 3, lastIndex * 2 / 3, lastIndex]
        let width: CGFloat = 72

        for (labelIndex, label) in xAxisLabels.enumerated() {
            let pointIndex = indices[labelIndex]
            let x          = position(for: pointIndex).x

            let originX: CGFloat
            switch label.textAlignment {
            case .left:  originX = plot.minX
            case .right: originX = plot.maxX - width
            default:     originX = x - width / 2
            }

            label.text     = format(date: points[pointIndex].date, with: axisDateFormatter)
            label.frame    = CGRect(x: originX, y: plot.maxY + 8, width: width, height: 14)
            label.isHidden = false
        }
    }

    private func format(date: Date, with formatter: DateFormatter) -> String {
        // pt_BR abrevia meses com ponto ("ago."); o protótipo usa sem.
        formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    // MARK: - Animações

    private func animateDrawIn() {
        let draw            = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue      = 0
        draw.toValue        = 1
        draw.duration       = 0.8
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lineLayer.add(draw, forKey: "draw")

        fadeIn(areaLayer, delay: 0.3, duration: 0.5)
        fadeIn(endHaloLayer, delay: 0.75, duration: 0.25)
        fadeIn(endDotLayer, delay: 0.75, duration: 0.25)

        let labels = yAxisLabels + xAxisLabels
        labels.forEach { $0.alpha = 0 }

        UIView.animate(withDuration: 0.3) {
            labels.forEach { $0.alpha = 1 }
        }
    }

    private func fadeIn(_ targetLayer: CALayer, delay: CFTimeInterval, duration: CFTimeInterval) {
        let fade       = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue   = 1
        fade.duration  = duration
        fade.beginTime = CACurrentMediaTime() + delay
        fade.fillMode  = .backwards
        targetLayer.add(fade, forKey: "fadeIn")
    }

    // MARK: - Tooltip (tocar e arrastar)

    @objc private func handleScrub(_ gesture: UILongPressGestureRecognizer) {
        let plot = plotRect
        guard points.count > 1, plot.width > 0 else { return }

        switch gesture.state {
        case .began, .changed:
            if gesture.state == .began {
                feedbackGenerator.prepare()
            }

            let progress = (gesture.location(in: self).x - plot.minX) / plot.width
            let index    = min(max(Int((progress * CGFloat(points.count - 1)).rounded()), 0), points.count - 1)

            guard index != scrubIndex else { return }

            scrubIndex = index
            feedbackGenerator.selectionChanged()
            showScrub(at: index)
        default:
            hideScrub()
        }
    }

    private func showScrub(at index: Int) {
        let plot  = plotRect
        let point = position(for: index)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let line = UIBezierPath()
        line.move(to: CGPoint(x: point.x, y: plot.minY))
        line.addLine(to: CGPoint(x: point.x, y: plot.maxY))

        scrubLineLayer.path     = line.cgPath
        scrubDotLayer.path      = UIBezierPath(ovalIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)).cgPath
        scrubLineLayer.isHidden = false
        scrubDotLayer.isHidden  = false

        CATransaction.commit()

        tooltipPriceLabel.text = points[index].price.asCurrency
        tooltipDateLabel.text  = format(date: points[index].date, with: tooltipDateFormatter)

        let width   = max(tooltipPriceLabel.intrinsicContentSize.width, tooltipDateLabel.intrinsicContentSize.width) + 24
        let originX = min(max(point.x - width / 2, 0), bounds.width - width)

        tooltipView.frame            = CGRect(x: originX, y: 0, width: width, height: 40)
        tooltipPriceLabel.frame      = CGRect(x: 0, y: 5, width: width, height: 18)
        tooltipDateLabel.frame       = CGRect(x: 0, y: 22, width: width, height: 14)
        tooltipView.layer.shadowPath = UIBezierPath(roundedRect: tooltipView.bounds, cornerRadius: 12).cgPath

        guard tooltipView.isHidden else { return }

        tooltipView.alpha    = 0
        tooltipView.isHidden = false

        UIView.animate(withDuration: 0.15) {
            self.tooltipView.alpha = 1
        }
    }

    private func hideScrub() {
        scrubIndex = nil

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scrubLineLayer.isHidden = true
        scrubDotLayer.isHidden  = true
        CATransaction.commit()

        guard !tooltipView.isHidden else { return }

        UIView.animate(withDuration: 0.15, animations: {
            self.tooltipView.alpha = 0
        }, completion: { _ in
            if self.scrubIndex == nil {
                self.tooltipView.isHidden = true
            }
        })
    }
}
