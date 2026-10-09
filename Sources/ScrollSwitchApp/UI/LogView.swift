import AppKit
import ScrollSwitchCore
import SwiftUI

/// The last 200 events, newest first (FR-13).
struct LogView: View {
    @ObservedObject var log: EventLog

    var body: some View {
        VStack(spacing: 0) {
            if log.events.isEmpty {
                ContentUnavailableLogPlaceholder()
            } else {
                List(log.events.reversed()) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: event.category.symbol)
                            .frame(width: 18)
                            .foregroundStyle(event.category == .error ? Color.red : Color.secondary)
                        Text(Self.time.string(from: event.date))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(event.message)
                            .font(.system(.body, design: .default))
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 1)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Text("\(log.events.count) of \(EventLog.capacity) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy All") {
                    let board = NSPasteboard.general
                    board.clearContents()
                    board.setString(log.transcript, forType: .string)
                }
                .disabled(log.events.isEmpty)
                Button("Clear") { log.clear() }
                    .disabled(log.events.isEmpty)
            }
            .padding(10)
        }
        .frame(minWidth: 520, minHeight: 320)
    }

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private struct ContentUnavailableLogPlaceholder: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No events yet")
                .font(.headline)
            Text("Dock or undock and they will show up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
