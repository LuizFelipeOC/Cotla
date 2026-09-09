//
//  LoadingOverlay.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit


class LoadingOverlay {
    static let shared = LoadingOverlay()
    private var overlayView: UIView?
    
    private init() {}
    
    @MainActor
    func show() {
        guard overlayView == nil,
              let window                = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene})
            .flatMap({ $0.windows })
            .first(where: {$0.isKeyWindow})
        else { return }
        
        let container                   = UIView(frame: window.bounds)
        container.backgroundColor       = UIColor.white.withAlphaComponent(0.3)
        container.autoresizingMask      = [.flexibleWidth, .flexibleHeight]
        
        let spinner                     = UIActivityIndicatorView(style: .large)
        spinner.color                   = UIColor(named: "BrandGreen")
        spinner.center                  = container.center
        spinner.autoresizingMask        = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        
        spinner.startAnimating()

        container.addSubview(spinner)
        window.addSubview(container)
        overlayView = container
    }
    
    @MainActor
    func hide() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
}



