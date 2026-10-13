//
//  DividendsSheetViewController.swift
//  cotla.app
//

import UIKit

final class DividendsSheetViewController: UIViewController {

    private let dividends: [CashDividendEntity]

    private let scrollView    = UIScrollView()
    private let dividendsCard = DividendsCardView()

    init(dividends: [CashDividendEntity]) {
        self.dividends = dividends
        super.init(nibName: nil, bundle: nil)

        if let sheet = sheetPresentationController {
            sheet.detents               = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(dividendsCard)

        dividendsCard.showsAll = true
        dividendsCard.display(dividends: dividends)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dividendsCard.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            dividendsCard.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            dividendsCard.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            dividendsCard.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }
}
