//
//  SceneDelegate.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
           let window = UIWindow(windowScene: windowScene)
        
           let defaults = UserDefaults.standard
           window.overrideUserInterfaceStyle = UIUserInterfaceStyle(rawValue: defaults.integer(forKey: WelcomeViewController.themeKey)) ?? .unspecified
           window.rootViewController = defaults.bool(forKey: WelcomeViewController.seenKey) ? MainTabBarController() : WelcomeViewController()
        
           self.window = window
           window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) { }

    func sceneDidBecomeActive(_ scene: UIScene) { }

    func sceneWillResignActive(_ scene: UIScene) { }

    /// Roda ao abrir o app e ao voltar para ele: traz o que mudou em outro aparelho e sobe o que ficou pendente.
    func sceneWillEnterForeground(_ scene: UIScene) {
        Task { await PortfolioSync.sync(from: window?.rootViewController) }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {}
}

