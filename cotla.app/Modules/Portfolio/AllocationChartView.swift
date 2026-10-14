//
//  AllocationChartView.swift
//  cotla.app
//

import UIKit

/// Rosca com a divisão da carteira por categoria, com legenda em %.
final class AllocationChartView: UIView {

    struct Slice {
        let kind: AssetKind
        let value: Double
    }

    private static let brazilLocale = Locale(identifier: "pt_BR")

    private let ringSize: CGFloat  = 110
    private let ringWidth: CGFloat = 16
    /// Espaço entre fatias, em fração da volta.
    private let sliceGap: CGFloat  = 0.006

    private let ringView    = UIView()
    private let legendStack = UIStackView()

    private var arcLayers: [AssetKind: CAShapeLayer] = [:]
    private var legendRows: [AssetKind: (row: UIStackView, percent: UILabel)] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        legendStack.axis    = .vertical
        legendStack.spacing = 8

        for kind in AssetKind.allCases {
            let arc         = CAShapeLayer()
            arc.fillColor   = UIColor.clear.cgColor
            arc.lineWidth   = ringWidth
            arc.strokeStart = 0
            arc.strokeEnd   = 0
            ringView.layer.addSublayer(arc)
            arcLayers[kind] = arc

            legendStack.addArrangedSubview(makeLegendRow(for: kind))
        }

        ringView.translatesAutoresizingMaskIntoConstraints = false

        let stack       = UIStackView(arrangedSubviews: [ringView, legendStack])
        stack.axis      = .horizontal
        stack.alignment = .center
        stack.spacing   = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            ringView.widthAnchor.constraint(equalToConstant: ringSize),
            ringView.heightAnchor.constraint(equalToConstant: ringSize),

            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        // As cores das fatias são CGColor e não acompanham o modo escuro sozinhas.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyColors()
        }
    }

    private func makeLegendRow(for kind: AssetKind) -> UIStackView {
        let dot                 = UIView()
        dot.backgroundColor     = kind.color
        dot.layer.cornerRadius  = 5
        dot.translatesAutoresizingMaskIntoConstraints = false

        let title       = SecondayLabelView(textAligment: .left, fontSize: 14)
        title.text      = kind.title
        title.textColor = .label

        let percent       = SecondayLabelView(textAligment: .right, fontSize: 14)
        percent.font      = .systemFont(ofSize: 14, weight: .semibold)
        percent.textColor = .secondaryLabel

        let row       = UIStackView(arrangedSubviews: [dot, title, percent])
        row.axis      = .horizontal
        row.alignment = .center
        row.spacing   = 8
        row.isHidden  = true

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10)
        ])

        legendRows[kind] = (row, percent)
        return row
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Tamanho fixo em vez de ringView.bounds: aqui a stack interna ainda não posicionou o ringView
        // (bounds zerado), e a rosca era desenhada em volta do canto (0, 0), vazando do card.
        let bounds = CGRect(x: 0, y: 0, width: ringSize, height: ringSize)
        let path   = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: (ringSize - ringWidth) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 3 / 2,
            clockwise: true
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for arc in arcLayers.values {
            arc.frame = bounds
            arc.path  = path.cgPath
        }
        CATransaction.commit()

        applyColors()
    }

    private func applyColors() {
        for (kind, arc) in arcLayers {
            arc.strokeColor = kind.color.resolvedColor(with: traitCollection).cgColor
        }
    }

    /// Categorias sem valor encolhem até sumir; a legenda só mostra as que têm valor.
    func setSlices(_ slices: [Slice], animated: Bool) {
        let total = slices.reduce(0) { $0 + $1.value }
        var start: CGFloat = 0

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.45)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        for kind in AssetKind.allCases {
            let value    = slices.first { $0.kind == kind }?.value ?? 0
            let fraction = total > 0 ? CGFloat(value / total) : 0
            let gap      = fraction > 0 && fraction < 1 ? sliceGap : 0

            arcLayers[kind]?.strokeStart = start + gap / 2
            arcLayers[kind]?.strokeEnd   = max(start + gap / 2, start + fraction - gap / 2)

            start += fraction

            legendRows[kind]?.percent.text = total > 0
                ? (value / total).formatted(.percent.precision(.fractionLength(1)).locale(Self.brazilLocale))
                : nil
        }

        CATransaction.commit()

        let updateLegend = {
            for kind in AssetKind.allCases {
                let isVisible = (slices.first { $0.kind == kind }?.value ?? 0) > 0
                self.legendRows[kind]?.row.isHidden = !isVisible
                self.legendRows[kind]?.row.alpha    = isVisible ? 1 : 0
            }
            self.legendStack.layoutIfNeeded()
        }

        animated ? UIView.animate(withDuration: 0.3, animations: updateLegend) : updateLegend()
    }
}

extension AssetKind {
    var color: UIColor {
        switch self {
        case .stock:    return UIColor(named: "BrandGreen") ?? .systemGreen
        case .fii:      return .systemBlue
        case .crypto:   return .systemOrange
        case .treasury: return .systemPurple
        }
    }
}
