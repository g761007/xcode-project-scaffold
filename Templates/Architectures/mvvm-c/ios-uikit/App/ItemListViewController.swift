import UIKit

final class ItemListViewController: UITableViewController {
    private let viewModel: ItemListViewModel
    private let cellIdentifier = "item"

    init(viewModel: ItemListViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; this view is created in code.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Items"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = viewModel.items[indexPath.row].title
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // The view controller reports the choice and stops there; the coordinator
        // decides what showing it means.
        viewModel.selectItem(at: indexPath.row)
    }
}
