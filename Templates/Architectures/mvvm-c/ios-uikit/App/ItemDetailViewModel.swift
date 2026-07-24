/// The detail screen's state: everything it shows, derived from the item it was
/// handed. No UIKit and no navigation — just presentation logic, so it can be
/// tested on its own.
@MainActor
final class ItemDetailViewModel {
    let title: String
    let detail: String

    init(item: Item) {
        title = item.title
        detail = "Item #\(item.id): \(item.title)"
    }
}
