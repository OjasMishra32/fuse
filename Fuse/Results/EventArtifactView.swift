import SwiftUI
import EventKit

// MARK: - Calendar event
//
// A calendar-style card with a month/day tile, then a one-tap "Add to Calendar" that
// uses EventKit's write-only access so we never read the user's calendar.

struct EventArtifactView: View {
    let event: CalendarEventArtifact
    @State private var state: AddState = .idle

    private static let store = EKEventStore()

    enum AddState: Equatable {
        case idle, adding, added
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResultCard {
                HStack(alignment: .top, spacing: 16) {
                    DateTile(date: event.startDate)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        DetailRow(symbol: "clock", text: whenText)
                        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                            DetailRow(symbol: "mappin.and.ellipse", text: location)
                        }
                        if !event.attendees.isEmpty {
                            DetailRow(symbol: "person.2", text: event.attendees.joined(separator: ", "))
                        }
                        if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                            InlineText(text: notes, font: .subheadline, color: .secondary)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                switch state {
                case .idle:
                    Button {
                        add()
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                case .adding:
                    WorkingLabel(title: "Adding…")
                case .added:
                    // The button flips to a confirmation whose checkmark bounces once as it lands.
                    StatusPill(title: "Added to Calendar", symbol: "checkmark", bounces: true)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                case .failed:
                    Button {
                        add()
                    } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }

            if case .failed(let message) = state {
                ErrorFootnote(message: message)
            }
        }
        .animation(Theme.snappy, value: state)
    }

    // MARK: Text

    private var whenText: String {
        if let start = event.startDate {
            let dayStyle = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
            if event.allDay {
                return "All day · \(start.formatted(dayStyle))"
            }
            if let end = event.endDate, end > start {
                if Calendar.current.isDate(start, inSameDayAs: end) {
                    return "\(start.formatted(dayStyle)) · \((start..<end).formatted(date: .omitted, time: .shortened))"
                }
                return (start..<end).formatted(date: .abbreviated, time: .shortened)
            }
            return start.formatted(date: .abbreviated, time: .shortened)
        }
        let raw = [event.start, event.end ?? ""].filter { !$0.isEmpty }
        return raw.isEmpty ? "Time to be confirmed" : raw.joined(separator: " – ")
    }

    // MARK: EventKit

    private func add() {
        state = .adding
        Haptics.tap()
        Task { @MainActor in
            do {
                let store = Self.store
                let granted = try await store.requestWriteOnlyAccessToEvents()
                guard granted else {
                    state = .failed("Calendar access was declined. You can allow it in Settings → Fuse.")
                    Haptics.warning()
                    return
                }
                let ekEvent = EKEvent(eventStore: store)
                ekEvent.title = event.title
                let start = event.startDate ?? Self.nextFullHour()
                ekEvent.startDate = start
                ekEvent.endDate = event.endDate.flatMap { $0 > start ? $0 : nil } ?? start.addingTimeInterval(3600)
                ekEvent.isAllDay = event.allDay
                ekEvent.location = event.location
                var notes = event.notes ?? ""
                if event.startDate == nil, !event.start.isEmpty {
                    notes += (notes.isEmpty ? "" : "\n\n") + "Original time: \(event.start)"
                }
                if !event.attendees.isEmpty {
                    notes += (notes.isEmpty ? "" : "\n\n") + "With: " + event.attendees.joined(separator: ", ")
                }
                ekEvent.notes = notes.isEmpty ? nil : notes
                guard let calendar = store.defaultCalendarForNewEvents else {
                    state = .failed("No calendar is available to add this event to.")
                    return
                }
                ekEvent.calendar = calendar
                try store.save(ekEvent, span: .thisEvent, commit: true)
                Haptics.success()
                state = .added
            } catch {
                Haptics.warning()
                state = .failed(error.localizedDescription)
            }
        }
    }

    private static func nextFullHour() -> Date {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        return (cal.date(from: comps) ?? now).addingTimeInterval(3600)
    }
}

// MARK: - Pieces

/// Month band over a large day number, like the Calendar app icon.
private struct DateTile: View {
    let date: Date?

    var body: some View {
        VStack(spacing: 0) {
            Text(month)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.accentColor)
            Text(day)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .padding(.top, 6)
            Text(weekday)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 1)
                .padding(.bottom, 8)
        }
        .frame(width: 60)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var month: String {
        guard let date else { return "Date" }
        return date.formatted(.dateTime.month(.abbreviated))
    }
    private var day: String {
        guard let date else { return "–" }
        return date.formatted(.dateTime.day())
    }
    private var weekday: String {
        guard let date else { return "TBD" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct DetailRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
