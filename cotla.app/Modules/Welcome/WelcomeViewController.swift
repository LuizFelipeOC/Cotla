//
//  WelcomeViewController.swift
//  cotla.app
//

import UIKit

final class WelcomeViewController: UIViewController {

    static let seenKey  = "hasSeenWelcome"
    static let themeKey = "userInterfaceStyle"

    private let brand       = UIColor(named: "BrandGreen") ?? .systemGreen
    private let ink         = UIColor { $0.userInterfaceStyle == .dark ? .label : UIColor(red: 0.059, green: 0.102, blue: 0.078, alpha: 1) }
    private let themeButton = UIButton(type: .system)
    private var barWidths: [NSLayoutConstraint] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? .systemBackground : UIColor(red: 0.949, green: 0.965, blue: 0.953, alpha: 1) }

        let counter  = UILabel()
        counter.text = "(01)"
        counter.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        counter.textColor = .secondaryLabel

        let pager = UIStackView(arrangedSubviews: [capsule(width: 20, color: brand), capsule(width: 6, color: .systemGray4), capsule(width: 6, color: .systemGray4)])
        pager.spacing   = 6
        pager.alignment = .center

        themeButton.backgroundColor    = .tertiarySystemBackground
        themeButton.tintColor          = ink
        themeButton.layer.cornerRadius = 20
        themeButton.accessibilityLabel = "Alternar tema"
        themeButton.addAction(UIAction { [weak self] _ in self?.toggleTheme() }, for: .primaryActionTriggered)
        addShadow(to: themeButton)
        updateThemeIcon()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: WelcomeViewController, _: UITraitCollection) in
            vc.updateThemeIcon()
        }

        let content     = makeContent()
        let startButton = makeStartButton()

        [counter, pager, themeButton, content, startButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let safe     = view.safeAreaLayoutGuide
        let centered = content.centerYAnchor.constraint(equalTo: safe.centerYAnchor)
        centered.priority = .defaultHigh

        NSLayoutConstraint.activate([
            themeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            themeButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            themeButton.widthAnchor.constraint(equalToConstant: 40),
            themeButton.heightAnchor.constraint(equalToConstant: 40),

            counter.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            counter.centerYAnchor.constraint(equalTo: themeButton.centerYAnchor),

            pager.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pager.centerYAnchor.constraint(equalTo: themeButton.centerYAnchor),

            content.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            content.topAnchor.constraint(greaterThanOrEqualTo: themeButton.bottomAnchor, constant: 24),
            content.bottomAnchor.constraint(lessThanOrEqualTo: startButton.topAnchor, constant: -24),
            centered,

            startButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            startButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            startButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !UIAccessibility.isReduceMotionEnabled else {
            NSLayoutConstraint.activate(barWidths)
            return
        }

        view.layoutIfNeeded()
        for (index, width) in barWidths.enumerated() {
            UIView.animate(withDuration: 0.9, delay: 0.12 * Double(index), usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
                width.isActive = true
                self.view.layoutIfNeeded()
            }
        }
    }

    private func makeContent() -> UIStackView {
        let title           = TitleLabelView(textAligment: .left, fontSize: 34)
        title.numberOfLines = 0
        title.textColor     = ink
        title.attributedText = NSAttributedString(string: "Sua carteira, organizada e sob controle.", attributes: [.kern: -0.8])

        let subtitle           = SecondayLabelView(textAligment: .left, fontSize: 17)
        subtitle.numberOfLines = 0
        subtitle.textColor     = .secondaryLabel
        subtitle.text          = "Acompanhe ativos, alocação e desempenho em tempo real — tudo em um só lugar."

        let bars       = UIStackView()
        bars.axis      = .vertical
        bars.spacing   = 8
        bars.alignment = .leading

        for (fraction, opacity) in [(0.18, 0.3), (0.27, 0.5), (0.36, 0.7), (0.5, 1.0)] {
            let bar                = UIView()
            bar.backgroundColor    = brand
            bar.alpha              = opacity
            bar.layer.cornerRadius = 8
            bar.layer.cornerCurve  = .continuous
            bars.addArrangedSubview(bar)

            // Starts at zero width; viewDidAppear activates the full width, which overrides it.
            let zero      = bar.widthAnchor.constraint(equalToConstant: 0)
            zero.priority = .init(999)
            NSLayoutConstraint.activate([bar.heightAnchor.constraint(equalToConstant: 28), zero])
            barWidths.append(bar.widthAnchor.constraint(equalTo: bars.widthAnchor, multiplier: fraction))
        }

        let stack = UIStackView(arrangedSubviews: [title, subtitle, bars])
        stack.axis = .vertical
        stack.setCustomSpacing(16, after: title)
        stack.setCustomSpacing(40, after: subtitle)
        return stack
    }

    private func makeStartButton() -> UIButton {
        var config                 = UIButton.Configuration.filled()
        config.baseBackgroundColor = brand
        config.baseForegroundColor = ink
        config.cornerStyle         = .fixed
        config.background.cornerRadius = 16
        config.image               = UIImage(systemName: "arrow.right")
        config.imagePlacement      = .trailing
        config.imagePadding        = 8
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(weight: .bold)

        var title  = AttributedString("Começar")
        title.font = .systemFont(ofSize: 17, weight: .bold)
        config.attributedTitle = title

        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.start() })
        addShadow(to: button)
        return button
    }

    private func capsule(width: CGFloat, color: UIColor) -> UIView {
        let view                = UIView()
        view.backgroundColor    = color
        view.layer.cornerRadius = 3
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: 6)
        ])
        return view
    }

    private func addShadow(to view: UIView) {
        view.layer.shadowColor   = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius  = 10
        view.layer.shadowOffset  = CGSize(width: 0, height: 4)
    }

    private func updateThemeIcon() {
        themeButton.setImage(UIImage(systemName: traitCollection.userInterfaceStyle == .dark ? "sun.max" : "moon"), for: .normal)
    }

    private func toggleTheme() {
        let style: UIUserInterfaceStyle = traitCollection.userInterfaceStyle == .dark ? .light : .dark
        view.window?.overrideUserInterfaceStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.themeKey)
    }

    private func start() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        guard let window = view.window else { return }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = MainTabBarController()
        }
    }
}
