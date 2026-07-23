import Testing
@testable import {{PROJECT_NAME}}

@MainActor
@Suite("Content view")
struct ContentViewTests {
    @Test("the view can be created")
    func viewCanBeCreated() {
        _ = ContentView()
    }
}
