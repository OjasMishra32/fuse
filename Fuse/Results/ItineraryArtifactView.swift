import SwiftUI
import MapKit
import CoreLocation

// MARK: - Itinerary
//
// A map fitted to every located stop, then each day as a vertical timeline. Stops are
// numbered globally so the marker on the map and the dot in the timeline always agree.

struct ItineraryArtifactView: View {
    let itinerary: Itinerary
    @Environment(\.fuseCompact) private var compact
    @State private var camera: MapCameraPosition = .automatic

    private struct LocatedStop: Identifiable {
        let id: Int           // global stop index
        let stop: Itinerary.Stop
        let coordinate: CLLocationCoordinate2D
    }

    private var located: [LocatedStop] {
        itinerary.allStops.enumerated().compactMap { index, stop in
            guard let lat = stop.latitude, let lon = stop.longitude,
                  lat.isFinite, lon.isFinite,
                  abs(lat) <= 90, abs(lon) <= 180 else { return nil }
            return LocatedStop(id: index, stop: stop, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    /// Number of stops that precede each day, so days can continue the global numbering.
    private var dayOffsets: [Int] {
        var offsets: [Int] = []
        var running = 0
        for day in itinerary.days {
            offsets.append(running)
            running += day.stops.count
        }
        return offsets
    }

    var body: some View {
        let stops = located
        VStack(alignment: .leading, spacing: 18) {
            if !stops.isEmpty {
                map(stops)
            }
            destinationLine

            ForEach(Array(itinerary.days.enumerated()), id: \.offset) { dayIndex, day in
                daySection(day, offset: dayOffsets[safe: dayIndex] ?? 0)
            }

            if itinerary.days.isEmpty {
                ResultCard {
                    Text("No stops were planned.")
                        .font(.fuseBody)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if !itinerary.tips.isEmpty {
                tips
            }
        }
    }

    // MARK: Map

    private func map(_ stops: [LocatedStop]) -> some View {
        Map(position: $camera, interactionModes: [.zoom]) {
            ForEach(stops) { item in
                Annotation(item.stop.name, coordinate: item.coordinate, anchor: .center) {
                    StopMarker(number: item.id + 1)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
        .frame(height: compact ? 200 : 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .onAppear {
            camera = .region(Self.region(fitting: stops.map(\.coordinate)))
        }
    }

    private static func region(fitting coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coords.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60))
        }
        if coords.count == 1 {
            return MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = min(max((maxLat - minLat) * 1.6, 0.015), 160)
        let lonDelta = min(max((maxLon - minLon) * 1.6, 0.015), 340)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    // MARK: Header line

    private var destinationLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.violet)
            Text(itinerary.destination)
                .font(.fuseHeadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(countLabel)
                .font(.fuseCaption)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var countLabel: String {
        let stops = itinerary.allStops.count
        let days = itinerary.days.count
        let stopText = stops == 1 ? "1 stop" : "\(stops) stops"
        let dayText = days == 1 ? "1 day" : "\(days) days"
        return days > 1 ? "\(stopText) · \(dayText)" : stopText
    }

    // MARK: Day timeline

    private func daySection(_ day: Itinerary.Day, offset: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: day.title)
            ResultCard {
                VStack(alignment: .leading, spacing: 0) {
                    if day.stops.isEmpty {
                        Text("Free day.")
                            .font(.fuseBody)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(Array(day.stops.enumerated()), id: \.offset) { index, stop in
                        StopRow(number: offset + index + 1, stop: stop, isLast: index == day.stops.count - 1)
                    }
                }
            }
        }
    }

    // MARK: Tips

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Tips")
            ResultCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(itinerary.tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.cyan)
                            InlineText(text: tip, color: Theme.textPrimary.opacity(0.9))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pieces

private struct StopMarker: View {
    let number: Int
    var body: some View {
        ZStack {
            Circle().fill(Theme.violet)
            Circle().stroke(.white.opacity(0.9), lineWidth: 2)
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 26, height: 26)
        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
    }
}

private struct StopRow: View {
    let number: Int
    let stop: Itinerary.Stop
    let isLast: Bool

    private var hasCoordinates: Bool {
        guard let lat = stop.latitude, let lon = stop.longitude else { return false }
        return lat.isFinite && lon.isFinite
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Theme.violet.opacity(0.16))
                    Circle().stroke(Theme.violet, lineWidth: 1.5)
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.violet)
                }
                .frame(width: 24, height: 24)
                if !isLast {
                    Rectangle()
                        .fill(Theme.line)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let time = stop.time, !time.isEmpty {
                    Text(time)
                        .font(.fuseMono)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(stop.name)
                    .font(.fuseHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = stop.note, !note.isEmpty {
                    InlineText(text: note, color: Theme.textSecondary)
                }
                if hasCoordinates {
                    MiniButton(title: "Open in Maps", symbol: "arrow.triangle.turn.up.right.diamond", tint: Theme.cyan) {
                        openInMaps()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func openInMaps() {
        guard let lat = stop.latitude, let lon = stop.longitude else { return }
        Haptics.tap()
        let location = CLLocation(latitude: lat, longitude: lon)
        let item = MKMapItem(location: location, address: nil)
        item.name = stop.name
        _ = item.openInMaps(launchOptions: nil)
    }
}
