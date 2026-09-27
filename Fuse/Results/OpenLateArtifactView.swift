import SwiftUI
import UIKit
import MapKit
import CoreLocation

// MARK: - Still open
//
// Late at night in a city you don't know: every place you can still reach and sit down at
// before it closes, soonest-closing first. A map with you and each numbered stop, then one
// row per place with its closing time, how long you'd get there, when to leave, and one tap
// to walking directions in Maps. Places you'd miss are listed with the reason.

struct OpenLateArtifactView: View {
    let plan: OpenLatePlan
    @Environment(\.fuseCompact) private var compact
    @State private var camera: MapCameraPosition = .automatic

    private var origin: CLLocationCoordinate2D? {
        OpenLateArtifactView.coordinate(plan.originLatitude, plan.originLongitude)
    }

    private struct LocatedSpot: Identifiable {
        let number: Int
        let spot: OpenLatePlan.Spot
        let coordinate: CLLocationCoordinate2D
        var id: Int { number }
    }

    private var located: [LocatedSpot] {
        plan.spots.enumerated().compactMap { index, spot in
            guard let coordinate = OpenLateArtifactView.coordinate(spot.latitude, spot.longitude) else { return nil }
            return LocatedSpot(number: index + 1, spot: spot, coordinate: coordinate)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !located.isEmpty {
                map
            }
            header

            if plan.spots.isEmpty {
                ContentUnavailableView(
                    "Nothing you can make tonight",
                    systemImage: "moon.zzz",
                    description: Text("Everything nearby closes before you could get there.")
                )
            } else {
                ResultCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(plan.spots.enumerated()), id: \.element.id) { index, spot in
                            SpotRow(number: index + 1, spot: spot)
                            if index < plan.spots.count - 1 {
                                Divider().padding(.leading, 38).padding(.vertical, 12)
                            }
                        }
                    }
                }
            }

            if !plan.missed.isEmpty {
                missed
            }

            if let tip = plan.tip?.trimmingCharacters(in: .whitespacesAndNewlines), !tip.isEmpty {
                Label {
                    InlineText(text: tip, color: Theme.textSecondary)
                } icon: {
                    Image(systemName: "lightbulb").foregroundStyle(Theme.cyan)
                }
                .font(.fuseCaption)
            }
        }
    }

    // MARK: Map

    private var map: some View {
        let stops = located
        return Map(position: $camera, interactionModes: [.zoom, .pan]) {
            if let origin {
                Annotation("You", coordinate: origin, anchor: .center) {
                    ZStack {
                        Circle().fill(.white).frame(width: 18, height: 18)
                        Circle().fill(Color.accentColor).frame(width: 12, height: 12)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                }
                .annotationTitles(.hidden)
            }
            ForEach(stops) { item in
                Marker(item.spot.name, monogram: Text("\(item.number)"), coordinate: item.coordinate)
                    .tint(OpenLateArtifactView.tint(for: item.spot))
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
        .frame(height: compact ? 200 : 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
        .onAppear {
            let coordinates = stops.map(\.coordinate) + (origin.map { [$0] } ?? [])
            camera = .region(OpenLateArtifactView.region(fitting: coordinates))
        }
        .accessibilityLabel("Map of \(stops.count) places still open")
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(plan.spots.count == 1 ? "1 place still open" : "\(plan.spots.count) places still open")
                .font(.fuseHeadline)
                .foregroundStyle(Theme.textPrimary)
            let from = plan.origin.trimmingCharacters(in: .whitespacesAndNewlines)
            let at = plan.now?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !from.isEmpty || !at.isEmpty {
                Text([from.isEmpty ? nil : "From \(from)", at.isEmpty ? nil : "at \(at)"].compactMap { $0 }.joined(separator: " "))
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Missed

    private var missed: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Too late tonight")
            ResultCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(plan.missed) { place in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.fuseBody)
                                .foregroundStyle(Theme.textSecondary)
                            if !place.reason.isEmpty {
                                Text(place.reason)
                                    .font(.fuseCaption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    static func coordinate(_ lat: Double?, _ lon: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lon, lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180, !(lat == 0 && lon == 0) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Tight on time (under half an hour to spare) reads orange; otherwise green.
    static func tint(for spot: OpenLatePlan.Spot) -> Color {
        guard let spare = spot.minutesToSpare else { return Color.accentColor }
        return spare < 30 ? .orange : .green
    }

    static func region(fitting coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coords.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(
            latitudeDelta: min(max((maxLat - minLat) * 1.5, 0.012), 160),
            longitudeDelta: min(max((maxLon - minLon) * 1.5, 0.012), 340)))
    }

    /// "in 1 hr 20 min" while the place closes within the next three hours, measured on the
    /// real clock; nil otherwise (a plan made for another time shows its own minutes to spare).
    static func countdown(to close: Date?, now: Date) -> String? {
        guard let close else { return nil }
        let minutes = Int(close.timeIntervalSince(now) / 60)
        guard minutes > 0, minutes <= 180 else { return nil }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "in \(m) min" }
        return m == 0 ? "in \(h) hr" : "in \(h) hr \(m) min"
    }
}

// MARK: - Row

private struct SpotRow: View {
    let number: Int
    let spot: OpenLatePlan.Spot

    private var tint: Color { OpenLateArtifactView.tint(for: spot) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.bold().monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.fuseHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                let details = [spot.category, spot.address].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TimelineView(.everyMinute) { context in
                    closing(now: context.date)
                }

                let timing = [spot.travel, spot.leaveBy.map { "Leave by \($0)" }]
                    .compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if !timing.isEmpty {
                    Label(timing.joined(separator: " · "), systemImage: travelSymbol)
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                }

                if let note = spot.note, !note.isEmpty {
                    InlineText(text: note, color: Theme.textSecondary)
                }

                if OpenLateArtifactView.coordinate(spot.latitude, spot.longitude) != nil || spot.address?.isEmpty == false {
                    Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill", action: directions)
                        .font(.fuseCaption.bold())
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(Color.accentColor)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func closing(now: Date) -> some View {
        let countdown = OpenLateArtifactView.countdown(to: spot.closesDate, now: now)
        var parts: [String] = []
        if !spot.closes.isEmpty { parts.append("Closes \(spot.closes)") }
        if let countdown { parts.append(countdown) }
        else if let spare = spot.minutesToSpare { parts.append("\(spare) min to spare") }
        return Text(parts.isEmpty ? "Hours not listed" : parts.joined(separator: " · "))
            .font(.fuseCaption.bold())
            .foregroundStyle(tint)
            .contentTransition(.numericText())
    }

    private var travelSymbol: String {
        let travel = (spot.travel ?? "").lowercased()
        if travel.contains("drive") || travel.contains("car") || travel.contains("taxi") || travel.contains("uber") { return "car.fill" }
        if travel.contains("train") || travel.contains("subway") || travel.contains("metro") || travel.contains("bus") { return "tram.fill" }
        return "figure.walk"
    }

    private func directions() {
        Haptics.tap()
        let mode = travelSymbol == "car.fill" ? MKLaunchOptionsDirectionsModeDriving
            : (travelSymbol == "tram.fill" ? MKLaunchOptionsDirectionsModeTransit : MKLaunchOptionsDirectionsModeWalking)
        if let coordinate = OpenLateArtifactView.coordinate(spot.latitude, spot.longitude) {
            let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
            item.name = spot.name
            _ = item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
        } else if let address = spot.address,
                  let query = "\(spot.name), \(address)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "maps://?daddr=\(query)&dirflg=w") {
            UIApplication.shared.open(url)
        }
    }
}
