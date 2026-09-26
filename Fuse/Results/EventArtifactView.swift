import SwiftUI
import EventKit

// MARK: - Calendar event
//
// A calendar-style card with a month/day tile, then a one-tap "Add to Calendar" that
// uses EventKit's write-only access so we never read the user's calendar.

struct EventArtifactView: View {
    let event: CalendarEventArtifact
    @Environment(\.fuseCompact) private var compact
    @State private var state: AddState = .idle

    private static let store = EKEventStore()

    enum AddState: Equatable {
        case idle, adding, added
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ResultCard {
                HStack(alignment: .top, spacing: 16) {
                    DateTile(date: event.startDate)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.fuseHeadline)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        DetailRow(symbol: "clock", text: whenText)
                        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                            DetailRow(symbol: "mappin.and.ellipse", text: location)
                        }
                        if !event.attendees.isEmpty {
                            DetailRow(symbol: "person.2", text: event.attendees.joined(separator: ", "))
                        }
                        if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                            InlineText(text: notes, color: Theme.textSecondary)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 10) {
                switch state {
                case .idle:
                    EnergyButton(title: "Add to Calendar", symbol: "calendar.badge.plus") { add() }
                case .adding:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(Theme.textSecondary)
                        Text("Adding…").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                case .added:
                    StatusPill(title: "Added to Calendar", symbol: "checkmark", tint: ResultPalette.good)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                case .failed:
                    EnergyButton(title: "Try again", symbol: "arrow.clockwise") { add() }
                }
            }

            if case .failed(let message) = state {
                Text(message)
                    .font(.fuseCaption)
                    .foregroundStyle(ResultPalette.bad)
                    .fixedSize(horizontal: false, vertical: true)
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

private struct DateTile: View {
    let date: Date?

    var body: some View {
        VStack(spacing: 0) {
            Text(month)
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Theme.violet)
            Text(day)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)
            Text(weekday)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 1)
                .padding(.bottom, 8)
        }
        .frame(width: 64)
        .background(Theme.ink3)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private var month: String {
        guard let date else { return "DATE" }
        return date.formatted(.dateTime.month(.abbreviated)).uppercased()
    }
    private var day: String {
        guard let date else { return "–" }
        return date.formatted(.dateTime.day())
    }
    private var weekday: String {
        guard let date else { return "TBD" }
        return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }
}

private struct DetailRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 16)
            Text(text)
                .font(.fuseBody)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
