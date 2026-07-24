import Testing
@testable import {{PROJECT_NAME}}

@MainActor
@Suite("Item list view model")
struct ItemListViewModelTests {
    @Test("selecting a row reports the item at that index")
    func selectReportsItem() {
        let items = [Item(id: 1, title: "One"), Item(id: 2, title: "Two")]
        let viewModel = ItemListViewModel(items: items)
        var selected: Item?
        viewModel.onSelect = { selected = $0 }

        viewModel.selectItem(at: 1)

        #expect(selected?.id == 2)
    }

    @Test("an out-of-range selection reports nothing")
    func outOfRangeReportsNothing() {
        let viewModel = ItemListViewModel(items: [Item(id: 1, title: "One")])
        var selected: Item?
        viewModel.onSelect = { selected = $0 }

        viewModel.selectItem(at: 5)

        #expect(selected == nil)
    }
}
