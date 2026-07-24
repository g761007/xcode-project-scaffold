import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // The view model is created here and injected into the view, so the view
        // holds no logic of its own — see App/GreetingViewModel.swift.
        let viewModel = GreetingViewModel(title: "{{PROJECT_NAME}}")
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootViewController(viewModel: viewModel)
        window.makeKeyAndVisible()
        self.window = window
    }
}
