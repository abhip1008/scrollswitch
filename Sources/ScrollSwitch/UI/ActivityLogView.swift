import ScrollSwitchCore
import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var log: EventLog

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(controller.stats.countThisWeek()) automatic switch\(controller.stats.countThisWeek() == 1 ? "" : "es") this week")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") { copy() }
                Button("Clear") { log.clear() }
            }
            .padding(10)
            Divider()
            if log.events.isEmpty {
                Spacer()
                Text("Nothing yet.").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(log.events) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: icon(event.kind))
                            .foregroundStyle(color(event.kind))
                            .frame(width: 16)
                        Text(event.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 150, alignment: .leading)
                        Text(event.message)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 300)
        .onAppear { activateApp() }
    }

    private func icon(_ kind: LogEvent.Kind) -> String {
        switch kind {
        case .info: return "info.circle"
        case .change: return "arrow.left.arrow.right.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private func color(_ kind: LogEvent.Kind) -> Color {
        switch kind {
        case .info: return .secondary
        case .change: return .accentColor
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func copy() {
        let text = log.events.reversed()
            .map { "\($0.date.formatted(date: .numeric, time: .standard)) [\($0.kind.rawValue)] \($0.message)" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
