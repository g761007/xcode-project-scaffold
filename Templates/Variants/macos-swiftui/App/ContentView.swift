import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(verbatim: "{{PROJECT_NAME}}")
            .font(.largeTitle)
    }
}

#Preview {
    ContentView()
}
