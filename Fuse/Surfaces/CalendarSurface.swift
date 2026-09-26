import SwiftUI
import EventKit
import UIKit
import Observation

// MARK: - Event

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var calendarName: String?
    var tint: Color

    init(id: String = UUID().uuidString, title: String, start: Date, end: Date, isAllDay: Bool = false,
         location: String? = nil, notes: String? = nil, calendarName: String? = nil, tint: Color = SurfaceKind.calendar.tint) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.calendarName = calendarName
        self.tint = tint
    }

    init(ekEvent: EKEvent) {
        id = ekEvent.eventIdentifier ?? UUID().uuidString
        title = ekEvent.title ?? "Untitled"
        start = ekEvent.startDate
        end = ekEvent.endDate
        isAllDay = ekEvent.isAllDay
        location = ekEvent.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        if location?.isEmpty == true { location = nil }
        notes = ekEvent.notes
        calendarName = ekEvent.calendar?.title
        if let cg = ekEvent.calendar?.cgColor {
            tint = Color(cgColor: cg)
        } else {
            tint = SurfaceKind.calendar.tint
        }
    }
}

// MARK: - Model

@MainActor
@Observable
final class CalendarSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .calendar

    enum Access: Equatable {
        case unknown, requesting, granted, denied
    }

    enum CalendarError: LocalizedError {
        case accessDenied
        case noCalendar

        var errorDescription: String? {
            switch self {
            case .accessDenied: "Calendar access was not granted."
            case .noCalendar: "No writable calendar is available."
            }
        }
    }

    private(set) var access: Access = .unknown
    private(set) var events: [CalendarEvent] = []
    private(set) var isSample: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var hasAutoLoaded = false

    init() {}

    // MARK: Derived

    struct DayGroup: Identifiable {
        let date: Date
        let events: [CalendarEvent]
        var id: Date { date }
    }

    var days: [DayGroup] {
        let cal = Calendar.current
        var buckets: [Date: [CalendarEvent]] = [:]
        for event in events {
            let day = cal.startOfDay(for: event.start)
            buckets[day, default: []].append(event)
        }
        return buckets.keys.sorted().map { day in
            DayGroup(date: day, events: buckets[day]!.sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.start < b.start
            })
        }
    }

    var windowEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    // MARK: SurfaceModel

    var headline: String {
        if events.isEmpty { return "Calendar" }
        let cal = Calendar.current
        if let next = events.filter({ $0.end >= .now }).min(by: { $0.start < $1.start }) {
            let label = cal.isDateInToday(next.start) ? "Today" : Self.dayFormatter.string(from: next.start)
            return "\(label): \(next.title)"
        }
        return "\(events.count) events"
    }

    var hasContent: Bool { !events.isEmpty }

    var thumbnail: UIImage? { nil }

    func capture() async -> SurfaceSnapshot {
        if events.isEmpty, access == .unknown {
            await refresh()
        }
        guard !events.isEmpty else { return .empty(.calendar) }

        let end = windowEnd
        let sorted = events.sorted { $0.start < $1.start }
        let thisWeek = sorted.filter { $0.start < end }
        let later = sorted.filter { $0.start >= end }

        var lines: [String] = ["EVENTS (next 7 days):"]
        if thisWeek.isEmpty {
            lines.append("(no events in the next 7 days)")
        } else {
            lines.append(contentsOf: thisWeek.map(Self.line(for:)))
        }
        if !later.isEmpty {
            lines.append("")
            lines.append("UPCOMING (beyond 7 days):")
            lines.append(contentsOf: later.map(Self.line(for:)))
        }

        let iso = Self.isoDayFormatter.string(from: .now)
        var meta: [String: String] = [
            "count": String(events.count),
            "today": iso,
            "windowEnd": Self.isoDayFormatter.string(from: end),
            "source": isSample ? "sample" : "eventkit"
        ]
        if let tz = TimeZone.current.abbreviation() { meta["timezone"] = tz }

        return SurfaceSnapshot(
            kind: .calendar,
            title: isSample ? "Sample week (\(events.count) events)" : "Next 7 days (\(thisWeek.count) events)",
            text: lines.joined(separator: "\n").fuseClipped(8000),
            image: nil,
            metadata: meta
        )
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .text, .url, .image, .place, .document:
            loadSampleWeek()
        }
    }

    func reset() {
        events = []
        isSample = false
        errorMessage = nil
        hasAutoLoaded = false
        if access != .granted { access = .unknown }
    }

    // MARK: Loading

    /// Called on first appearance. Requests access and lists the next 7 days.
    func loadIfNeeded() {
        guard !hasAutoLoaded else { return }
        hasAutoLoaded = true
        Task { await refresh() }
    }

    func refresh() async {
        guard !isSample else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let status = EKEventStore.authorizationStatus(for: .event)
        var granted = status == .fullAccess
        if status == .notDetermined || status == .writeOnly {
            access = .requesting
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        }
        guard granted else {
            access = .denied
            return
        }
        access = .granted
        store.reset()

        let start = Calendar.current.startOfDay(for: .now)
        let predicate = store.predicateForEvents(withStart: start, end: windowEnd, calendars: nil)
        let fetched = store.events(matching: predicate)
            .map(CalendarEvent.init(ekEvent:))
            .sorted { $0.start < $1.start }
        events = fetched
    }

    func loadSampleWeek() {
        Haptics.soft()
        isSample = true
        errorMessage = nil
        events = Self.sampleEvents()
    }

    func useRealCalendar() {
        isSample = false
        events = []
        Task { await refresh() }
    }

    /// Adds an event to the user's default calendar. Also mirrors it into the in-memory list.
    func addEvent(title: String, start: Date, end: Date, location: String? = nil, notes: String? = nil) async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        var granted = status == .fullAccess || status == .writeOnly
        if status == .notDetermined {
            granted = try await store.requestFullAccessToEvents()
        }
        guard granted else { throw CalendarError.accessDenied }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.location = location
        event.notes = notes
        guard let calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first(where: { $0.allowsContentModifications }) else {
            throw CalendarError.noCalendar
        }
        event.calendar = calendar
        try store.save(event, span: .thisEvent, commit: true)

        let mirrored = CalendarEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: title, start: start, end: end,
            location: location, notes: notes, calendarName: calendar.title,
            tint: Color(cgColor: calendar.cgColor)
        )
        if isSample {
            events.append(mirrored)
            events.sort { $0.start < $1.start }
        } else {
            await refresh()
            if !events.contains(where: { $0.id == mirrored.id }), start < windowEnd {
                events.append(mirrored)
                events.sort { $0.start < $1.start }
            }
        }
        Haptics.success()
    }

    // MARK: Sample data

    /// A plausible student/founder week starting today, plus a fixed Nov 20–22, 2026 weekend so the
    /// conference-email demo ("Fold it into my week") produces real conflicts.
    static func sampleEvents(now: Date = .now) -> [CalendarEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        func fixed(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            var comps = DateComponents()
            comps.year = 2026; comps.month = month; comps.day = day; comps.hour = hour; comps.minute = minute
            return cal.date(from: comps) ?? today
        }
        func ev(_ title: String, _ start: Date, minutes: Int, location: String? = nil, notes: String? = nil, tint: Color = SurfaceKind.calendar.tint) -> CalendarEvent {
            CalendarEvent(title: title, start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                          location: location, notes: notes, calendarName: "Sample", tint: tint)
        }

        let classes = Theme.cyan
        let founder = Theme.violet
        let personal = Theme.mint
        let travel = Theme.magenta

        var list: [CalendarEvent] = [
            ev("Bitrig Hacks demo", at(0, 18), minutes: 120, location: "YC SF", notes: "Bring the Duo + charger.", tint: founder),
            ev("Brunch with cofounders", at(1, 11), minutes: 90, location: "Se7en Bites, Orlando", tint: personal),
            ev("Distributed Systems lecture", at(2, 9, 35), minutes: 50, location: "CSE E222", tint: classes),
            ev("Office hours — Dr. Patel", at(2, 14), minutes: 45, location: "Malachowsky Hall 4th floor", tint: classes),
            ev("Gym", at(3, 7), minutes: 60, location: "Southwest Rec", tint: personal),
            ev("Investor intro call", at(3, 16), minutes: 30, location: "Zoom", notes: "Seed round, warm intro via Maya.", tint: founder),
            ev("Product sync", at(4, 10), minutes: 45, location: "Discord", tint: founder),
            ev("Hackathon retro dinner", at(4, 19), minutes: 120, location: "Hawkers, Mills 50", tint: personal),
            ev("Flight MCO → SFO", at(5, 8, 15), minutes: 390, location: "Orlando International (MCO)", notes: "Terminal C. Seat 14A.", tint: travel),
            ev("Demo day prep", at(6, 13), minutes: 180, location: "Coworking, SoMa", tint: founder),
            // Fixed conflict weekend for the Swiftsonic Nashville demo (Nov 20–22, 2026).
            ev("Dentist", fixed(11, 20, 10), minutes: 60, location: "Ocala", tint: personal),
            ev("Dinner with Sam", fixed(11, 21, 19), minutes: 120, location: "The Ravenous Pig, Winter Park", tint: personal),
            ev("Flight home", fixed(11, 22, 14), minutes: 180, location: "Orlando International (MCO)", tint: travel)
        ]
        list.sort { $0.start < $1.start }
        return list
    }

    // MARK: Formatting

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE MMM d"
        return f
    }()

    static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    static let dayHeaderWithYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    static let captureDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE MMM d yyyy"
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func line(for event: CalendarEvent) -> String {
        var line = captureDateFormatter.string(from: event.start)
        if event.isAllDay {
            line += " all day"
        } else {
            line += " " + timeFormatter.string(from: event.start) + "–" + timeFormatter.string(from: event.end)
        }
        line += " – " + event.title
        if let location = event.location, !location.isEmpty { line += " @ " + location }
        return line
    }

    static func header(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        if cal.isDate(day, equalTo: .now, toGranularity: .year) {
            return dayHeaderFormatter.string(from: day)
        }
        return dayHeaderWithYearFormatter.string(from: day)
    }
}

// MARK: - View

/// The week as an inset-grouped list, one section per day, a dot per event. A glass pill
/// at the top says which week this is; the list scrolls underneath it.
struct CalendarSurfaceView: View {
    let model: CalendarSurfaceModel

    private let accent = Color(uiColor: .systemRed)

    var body: some View {
        ZStack {
            Theme.grouped.ignoresSafeArea()

            if model.hasContent {
                eventList
                    .transition(.opacity)
            } else if model.isLoading || model.access == .requesting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(model.access == .requesting ? "Waiting for calendar access…" : "Reading your week…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                emptyState
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.snappy, value: model.hasContent)
        .onAppear { model.loadIfNeeded() }
    }

    // MARK: Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label(model.access == .denied ? "Calendar Access Is Off" : "Nothing This Week",
                  systemImage: model.access == .denied ? "calendar.badge.exclamationmark" : "calendar")
        } description: {
            Text(model.access == .denied
                 ? "Allow access in Settings, or load a sample week to try the fuse."
                 : "Your next 7 days are clear. Load a sample week to see how events fuse with the other screen.")
        } actions: {
            VStack(spacing: 8) {
                Button {
                    model.loadSampleWeek()
                } label: {
                    Label("Load Sample Week", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                if model.access == .denied {
                    Button("Open Settings") {
                        Haptics.tap()
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                } else if model.access == .granted {
                    Button("Refresh") {
                        Haptics.tap()
                        Task { await model.refresh() }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: List

    private var eventList: some View {
        List {
            ForEach(model.days) { day in
                Section {
                    ForEach(day.events) { event in
                        eventRow(event)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } header: {
                    dayHeader(day.date)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { toolbar }
    }

    private var toolbar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: model.isSample ? "sparkles" : "calendar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                    Text(model.isSample ? "Sample Week" : "Next 7 Days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(model.events.count == 1 ? "1 event" : "\(model.events.count) events")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)

                if model.isSample {
                    Button {
                        Haptics.tap()
                        model.useRealCalendar()
                    } label: {
                        iconLabel("arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use My Calendar")
                } else {
                    Button {
                        Haptics.tap()
                        Task { await model.refresh() }
                    } label: {
                        iconLabel("arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func iconLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    private func dayHeader(_ date: Date) -> some View {
        let today = Calendar.current.isDateInToday(date)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(CalendarSurfaceModel.header(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(today ? accent : .primary)
            if today || Calendar.current.isDateInTomorrow(date) {
                Text(CalendarSurfaceModel.dayFormatter.string(from: date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(model.isSample ? accent : event.tint)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(detail(for: event))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(for event: CalendarEvent) -> String {
        var parts: [String] = []
        if event.isAllDay {
            parts.append("All day")
        } else {
            parts.append(CalendarSurfaceModel.timeFormatter.string(from: event.start) + " – " + CalendarSurfaceModel.timeFormatter.string(from: event.end))
        }
        if let location = event.location, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}
