import SwiftUI

struct ContentView: View {
    /// Owned by the view but created outside it, so a test — or a preview — can
    /// supply its own. See App/GreetingViewModel.swift for the logic itself.
    @State private var viewModel: GreetingViewModel

    init(viewModel: GreetingViewModel = GreetingViewModel(title: "{{PROJECT_NAME}}")) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.title)
                .font(.largeTitle)
            Text(viewModel.tapCountText)
            Button("Tap me") {
                viewModel.registerTap()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
