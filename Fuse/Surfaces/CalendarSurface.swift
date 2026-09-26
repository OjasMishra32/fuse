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

struct CalendarSurfaceView: View {
    let model: CalendarSurfaceModel

    var body: some View {
        ZStack {
            Theme.ink2.ignoresSafeArea()

            if model.hasContent {
                eventList
                    .transition(.opacity)
            } else if model.isLoading || model.access == .requesting {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(SurfaceKind.calendar.tint)
                    Text(model.access == .requesting ? "Waiting for calendar access…" : "Reading your week…")
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                emptyState
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
        .animation(Theme.snappy, value: model.hasContent)
        .onAppear { model.loadIfNeeded() }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            SurfaceEmptyState(
                symbol: model.access == .denied ? "calendar.badge.exclamationmark" : "calendar",
                title: model.access == .denied ? "Calendar access is off" : "Nothing this week",
                hint: model.access == .denied
                    ? "Allow access in Settings, or load a sample week to try the fuse."
                    : "Your next 7 days are clear. Load a sample week to see how events fuse with the other screen.",
                tint: SurfaceKind.calendar.tint
            )
            .frame(maxHeight: 200)

            EnergyButton(title: "Load sample week", symbol: "sparkles") {
                model.loadSampleWeek()
            }

            if model.access == .denied {
                GlassButton(title: "Open Settings", symbol: "gear") {
                    Haptics.tap()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else if model.access == .granted {
                GlassButton(title: "Refresh", symbol: "arrow.clockwise") {
                    Haptics.tap()
                    Task { await model.refresh() }
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: List

    private var eventList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: model.isSample ? "sparkles" : "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SurfaceKind.calendar.tint)
                    Text(model.isSample ? "Sample week" : "Next 7 days")
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: .capsule)

                Spacer(minLength: 0)

                Text(model.events.count == 1 ? "1 event" : "\(model.events.count) events")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()

                if model.isSample {
                    Button {
                        Haptics.tap()
                        model.useRealCalendar()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 30, height: 30)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Haptics.tap()
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 30, height: 30)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    ForEach(model.days) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(CalendarSurfaceModel.header(for: day.date))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Calendar.current.isDateInToday(day.date) ? SurfaceKind.calendar.tint : Theme.textPrimary)
                                if Calendar.current.isDateInToday(day.date) || Calendar.current.isDateInTomorrow(day.date) {
                                    Text(CalendarSurfaceModel.dayFormatter.string(from: day.date))
                                        .font(.fuseCaption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 4) {
                                ForEach(day.events) { event in
                                    eventRow(event)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                if event.isAllDay {
                    Text("All day")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text(CalendarSurfaceModel.timeFormatter.string(from: event.start))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(CalendarSurfaceModel.timeFormatter.string(from: event.end))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 58, alignment: .trailing)
            .monospacedDigit()

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.tint)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10, weight: .semibold))
                        Text(location)
                            .lineLimit(1)
                    }
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.ink3.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
    }
}
