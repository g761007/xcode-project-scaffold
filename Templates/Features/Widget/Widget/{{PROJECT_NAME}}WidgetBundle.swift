import SwiftUI
import WidgetKit

/// The extension's entry point: every widget it offers, declared in one place.
/// A second widget is a second line here and a second `Widget` type.
@main
struct {{PROJECT_NAME}}WidgetBundle: WidgetBundle {
    var body: some Widget {
        {{PROJECT_NAME}}Widget()
    }
}
