import UIKit

/// Owns the navigation and decides what each screen leads to. The view
/// controllers report intent — a selection — and the coordinator, not they,
/// creates and pushes the next screen. That is the "C" in MVVM-C, and it is
/// what keeps navigation testable and the screens unaware of one another.
@MainActor
final class AppCoordinator {
    let navigationController = UINavigationController()

    func start() {
        let listViewModel = ItemListViewModel()
        listViewModel.onSelect = { [weak self] item in
            self?.showDetail(for: item)
        }
        navigationController.viewControllers = [ItemListViewController(viewModel: listViewModel)]
    }

    private func showDetail(for item: Item) {
        let detail = ItemDetailViewController(viewModel: ItemDetailViewModel(item: item))
        navigationController.pushViewController(detail, animated: true)
    }
}
