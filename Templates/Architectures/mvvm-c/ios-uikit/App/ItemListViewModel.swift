/// One item in the list — the "Model" in MVVM-C: plain data, no behaviour.
struct Item: Identifiable, Sendable {
    let id: Int
    let title: String
}

extension Item {
    /// Stand-in data so the example runs; replace it with your own source.
    static let sample = [
        Item(id: 1, title: "First item"),
        Item(id: 2, title: "Second item"),
        Item(id: 3, title: "Third item")
    ]
}

/// The list screen's state. It owns the items and reports which one was chosen;
/// deciding what "chosen" leads to is the coordinator's job, not the view
/// model's. That separation is what MVVM-C adds over MVVM.
@MainActor
final class ItemListViewModel {
    let items: [Item]

    /// Called with the chosen item so the coordinator can route to it. Keeping
    /// navigation out of the view model is the whole point of the pattern.
    var onSelect: ((Item) -> Void)?

    init(items: [Item] = Item.sample) {
        self.items = items
    }

    func selectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        onSelect?(items[index])
    }
}
