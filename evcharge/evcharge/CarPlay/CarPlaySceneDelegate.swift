//
//  CarPlaySceneDelegate.swift
//  evcharge
//

import CarPlay
import UIKit

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var sessionManager: CarPlaySessionManager?

    // UISceneDelegate — verbindet CPTemplateApplicationScene.delegate explizit
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let templateScene = scene as? CPTemplateApplicationScene {
            templateScene.delegate = self
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let manager = CarPlaySessionManager(interfaceController: interfaceController)
        self.sessionManager = manager
        manager.start()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        sessionManager?.stop()
        sessionManager = nil
        self.interfaceController = nil
    }
}
