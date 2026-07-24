import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // The coordinator owns the navigation stack; the scene just hands it the
        // window and keeps it alive. See App/AppCoordinator.swift.
        let coordinator = AppCoordinator()
        coordinator.start()
        self.coordinator = coordinator

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = coordinator.navigationController
        window.makeKeyAndVisible()
        self.window = window
    }
}
