import SwiftUI
import WidgetKit

/// The smallest timeline that shows something: one entry, and a policy that
/// never asks for another. Replace both with the real data and the real
/// refresh cadence — a widget that never reloads is the starting point, not
/// the destination.
struct {{PROJECT_NAME}}TimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> {{PROJECT_NAME}}Entry {
        {{PROJECT_NAME}}Entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping ({{PROJECT_NAME}}Entry) -> Void) {
        completion({{PROJECT_NAME}}Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<{{PROJECT_NAME}}Entry>) -> Void) {
        completion(Timeline(entries: [{{PROJECT_NAME}}Entry(date: .now)], policy: .never))
    }
}

struct {{PROJECT_NAME}}Entry: TimelineEntry {
    let date: Date
}

struct {{PROJECT_NAME}}WidgetView: View {
    var entry: {{PROJECT_NAME}}Entry

    /// The container background is required from iOS 17 — a widget that skips
    /// it there draws on nothing — and does not exist before it. This project
    /// deploys to {{DEPLOYMENT_TARGET}}, and the check keeps the widget correct
    /// whichever side of that line the target sits on.
    var body: some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(.fill.tertiary, for: .widget)
        } else {
            content
        }
    }

    private var content: some View {
        VStack {
            Text("{{PROJECT_NAME}}")
                .font(.headline)
            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct {{PROJECT_NAME}}Widget: Widget {
    /// The identifier WidgetKit stores timelines under. Changing it after
    /// release orphans every widget already on a home screen.
    let kind = "{{PROJECT_NAME}}Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: {{PROJECT_NAME}}TimelineProvider()) { entry in
            {{PROJECT_NAME}}WidgetView(entry: entry)
        }
        .configurationDisplayName("{{PROJECT_NAME}}")
        .description("The {{PROJECT_NAME}} widget.")
    }
}
