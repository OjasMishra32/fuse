import SwiftUI
import MapKit
import CoreLocation

// MARK: - Itinerary
//
// A map fitted to every located stop, then each day as a vertical timeline. Stops are
// numbered globally so the marker on the map and the number in the timeline always agree.

struct ItineraryArtifactView: View {
    let itinerary: Itinerary
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
        VStack(alignment: .leading, spacing: 16) {
            if !stops.isEmpty {
                map(stops)
            }
            destinationLine

            ForEach(Array(itinerary.days.enumerated()), id: \.offset) { dayIndex, day in
                daySection(day, offset: dayOffsets[safe: dayIndex] ?? 0)
            }

            if itinerary.days.isEmpty {
                EmptyArtifactCard(text: "No stops were planned.")
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
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .onAppear {
            camera = .region(Self.region(fitting: stops.map(\.coordinate)))
        }
        .accessibilityLabel("Map of \(stops.count) \(stops.count == 1 ? "stop" : "stops")")
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(itinerary.destination)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(countLabel)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
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
        ResultSection(title: day.title) {
            ResultCard {
                VStack(alignment: .leading, spacing: 0) {
                    if day.stops.isEmpty {
                        Text("Free day.")
                            .font(.body)
                            .foregroundStyle(.secondary)
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
        ResultSection(title: "Tips") {
            ResultCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(itinerary.tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "lightbulb")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            InlineText(text: tip)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pieces

/// Numbered accent marker on the map, like a Maps guide pin.
private struct StopMarker: View {
    let number: Int
    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Color.accentColor, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .accessibilityLabel("Stop \(number)")
    }
}

/// One stop: a 12pt dot on a hairline timeline, then time, name, note and Open in Maps.
private struct StopRow: View {
    let number: Int
    let stop: Itinerary.Stop
    let isLast: Bool

    private var hasCoordinates: Bool {
        guard let lat = stop.latitude, let lon = stop.longitude else { return false }
        return lat.isFinite && lon.isFinite
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(Theme.line)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                if let time = stop.time?.trimmingCharacters(in: .whitespaces), !time.isEmpty {
                    Text(time)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(number)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(stop.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = stop.note, !note.isEmpty {
                    InlineText(text: note, font: .subheadline, color: .secondary)
                }
                if hasCoordinates {
                    MiniButton(title: "Open in Maps", symbol: "arrow.triangle.turn.up.right.diamond") {
                        openInMaps()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
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
