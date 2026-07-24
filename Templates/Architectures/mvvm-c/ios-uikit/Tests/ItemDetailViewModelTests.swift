import Testing
@testable import {{PROJECT_NAME}}

@MainActor
@Suite("Item detail view model")
struct ItemDetailViewModelTests {
    @Test("it presents the item it was given")
    func presentsItem() {
        let viewModel = ItemDetailViewModel(item: Item(id: 7, title: "Widget"))

        #expect(viewModel.title == "Widget")
        #expect(viewModel.detail == "Item #7: Widget")
    }
}
