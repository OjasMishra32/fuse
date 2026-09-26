import SwiftUI
import MapKit
import CoreLocation
import UIKit
import Observation

// MARK: - Place

struct MapPlace: Identifiable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var category: String?
    var categorySymbol: String
    var phone: String?
    var url: URL?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinateText: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }

    static func == (lhs: MapPlace, rhs: MapPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    @MainActor
    init(mapItem: MKMapItem) {
        id = UUID()
        name = mapItem.name ?? "Unnamed place"
        let placemark = mapItem.placemark
        address = MapPlace.formatAddress(placemark)
        category = mapItem.pointOfInterestCategory.map(MapPlace.label(for:))
        categorySymbol = MapPlace.symbol(for: mapItem.pointOfInterestCategory)
        phone = mapItem.phoneNumber
        url = mapItem.url
        latitude = placemark.coordinate.latitude
        longitude = placemark.coordinate.longitude
    }

    init(name: String, address: String, latitude: Double, longitude: Double, category: String? = nil, symbol: String = "mappin") {
        id = UUID()
        self.name = name
        self.address = address
        self.category = category
        categorySymbol = symbol
        phone = nil
        url = nil
        self.latitude = latitude
        self.longitude = longitude
    }

    static func formatAddress(_ placemark: MKPlacemark) -> String {
        var parts: [String] = []
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        if !street.isEmpty { parts.append(street) }
        if let locality = placemark.locality { parts.append(locality) }
        let regionLine = [placemark.administrativeArea, placemark.postalCode].compactMap { $0 }.joined(separator: " ")
        if !regionLine.isEmpty { parts.append(regionLine) }
        if parts.isEmpty, let title = placemark.title { return title }
        return parts.joined(separator: ", ")
    }

    static func label(for category: MKPointOfInterestCategory) -> String {
        var raw = category.rawValue
        if raw.hasPrefix("MKPOICategory") { raw.removeFirst("MKPOICategory".count) }
        var out = ""
        for (i, ch) in raw.enumerated() {
            if ch.isUppercase && i > 0 { out.append(" ") }
            out.append(ch)
        }
        return out
    }

    static func symbol(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "mappin" }
        switch category {
        case .restaurant, .bakery: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .hotel: return "bed.double.fill"
        case .amusementPark: return "sparkles"
        case .airport: return "airplane"
        case .store, .foodMarket: return "bag.fill"
        case .park, .nationalPark: return "tree.fill"
        case .museum: return "building.columns.fill"
        case .gasStation, .evCharger: return "fuelpump.fill"
        case .hospital, .pharmacy: return "cross.case.fill"
        case .school, .university: return "graduationcap.fill"
        case .stadium: return "sportscourt.fill"
        case .theater, .movieTheater: return "theatermasks.fill"
        case .beach: return "beach.umbrella.fill"
        case .nightlife, .brewery, .winery: return "wineglass.fill"
        case .parking: return "parkingsign"
        case .publicTransport: return "tram.fill"
        case .fitnessCenter: return "figure.run"
        case .library: return "books.vertical.fill"
        case .bank, .atm: return "banknote.fill"
        default: return "mappin"
        }
    }
}

// MARK: - Model

@MainActor
@Observable
final class MapSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .maps

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.4743, longitude: -81.4677),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )

    struct QuickSearch: Identifiable {
        let title: String
        let symbol: String
        var id: String { title }
    }

    static let quickSearches: [QuickSearch] = [
        QuickSearch(title: "Universal Studios", symbol: "sparkles"),
        QuickSearch(title: "Coffee", symbol: "cup.and.saucer.fill"),
        QuickSearch(title: "Hotels", symbol: "bed.double.fill"),
        QuickSearch(title: "Dinner", symbol: "fork.knife")
    ]

    var query: String = ""
    var cameraPosition: MapCameraPosition = .region(MapSurfaceModel.defaultRegion)
    var selectedID: UUID?
    private(set) var visibleRegion: MKCoordinateRegion = MapSurfaceModel.defaultRegion
    private(set) var results: [MapPlace] = []
    private(set) var lastQuery: String = ""
    private(set) var isSearching: Bool = false
    private(set) var searchError: String?
    private(set) var lastSnapshot: UIImage?

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?

    init() {}

    var selected: MapPlace? {
        guard let id = selectedID else { return nil }
        return results.first { $0.id == id }
    }

    // MARK: SurfaceModel

    var headline: String {
        if let selected { return selected.name }
        if !lastQuery.isEmpty { return "\(results.count) results for \"\(lastQuery)\"" }
        return "Map"
    }

    var hasContent: Bool { selected != nil || !results.isEmpty }

    var thumbnail: UIImage? { lastSnapshot }

    func capture() async -> SurfaceSnapshot {
        let region = visibleRegion
        let selected = selected

        var title: String
        if let selected {
            title = selected.name
        } else {
            let label = await regionDescription(for: region)
            title = "Map around \(label)"
        }

        var lines: [String] = []
        var meta: [String: String] = [:]

        if let selected {
            lines.append("SELECTED PLACE")
            lines.append("Name: \(selected.name)")
            if !selected.address.isEmpty { lines.append("Address: \(selected.address)") }
            if let category = selected.category { lines.append("Category: \(category)") }
            if let phone = selected.phone { lines.append("Phone: \(phone)") }
            if let url = selected.url { lines.append("Website: \(url.absoluteString)") }
            lines.append("Coordinates: \(selected.coordinateText)")
            meta["name"] = selected.name
            meta["address"] = selected.address
            meta["latitude"] = String(format: "%.6f", selected.latitude)
            meta["longitude"] = String(format: "%.6f", selected.longitude)
            if let category = selected.category { meta["category"] = category }
            if let phone = selected.phone { meta["phone"] = phone }
            if let url = selected.url { meta["url"] = url.absoluteString }
        } else {
            meta["latitude"] = String(format: "%.6f", region.center.latitude)
            meta["longitude"] = String(format: "%.6f", region.center.longitude)
        }

        meta["centerLatitude"] = String(format: "%.6f", region.center.latitude)
        meta["centerLongitude"] = String(format: "%.6f", region.center.longitude)
        meta["spanLatitude"] = String(format: "%.4f", region.span.latitudeDelta)
        if !lastQuery.isEmpty { meta["query"] = lastQuery }
        meta["resultCount"] = String(results.count)

        if !results.isEmpty {
            if !lines.isEmpty { lines.append("") }
            let header = lastQuery.isEmpty ? "VISIBLE RESULTS (\(results.count)):" : "VISIBLE RESULTS (\(results.count)) for \"\(lastQuery)\":"
            lines.append(header)
            for (i, place) in results.prefix(25).enumerated() {
                var line = "\(i + 1). \(place.name)"
                if !place.address.isEmpty { line += " — \(place.address)" }
                if let category = place.category { line += " (\(category))" }
                line += " @ \(place.coordinateText)"
                lines.append(line)
            }
        }

        if lines.isEmpty {
            lines.append("Map view centred on \(title). No pins or search results.")
        }

        let image = await renderSnapshot(region: region, size: CGSize(width: 900, height: 680))
        if let image { lastSnapshot = image }

        return SurfaceSnapshot(
            kind: .maps,
            title: title,
            text: lines.joined(separator: "\n").fuseClipped(8000),
            image: image?.fuseDownscaled(maxEdge: 1024),
            metadata: meta
        )
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .place(let name, let latitude, let longitude):
            let place = MapPlace(name: name, address: "", latitude: latitude, longitude: longitude)
            searchTask?.cancel()
            isSearching = false
            results = [place]
            lastQuery = ""
            query = name
            select(place, animated: true)
            Task { [weak self] in
                let address = await MapSurfaceModel.reverseGeocode(latitude: latitude, longitude: longitude)
                guard let self, let address, !address.isEmpty else { return }
                if let idx = self.results.firstIndex(where: { $0.id == place.id }) {
                    self.results[idx].address = address
                }
            }
        case .text(let text):
            query = text
            runSearch()
        case .url, .image, .document:
            break
        }
    }

    func reset() {
        searchTask?.cancel()
        thumbnailTask?.cancel()
        query = ""
        lastQuery = ""
        results = []
        selectedID = nil
        isSearching = false
        searchError = nil
        lastSnapshot = nil
        visibleRegion = Self.defaultRegion
        cameraPosition = .region(Self.defaultRegion)
    }

    // MARK: Interaction

    func cameraDidSettle(_ region: MKCoordinateRegion) {
        visibleRegion = region
        scheduleThumbnailRefresh()
    }

    func runSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        searchError = nil
        let region = visibleRegion
        searchTask = Task { [weak self] in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            request.region = region
            request.resultTypes = [.pointOfInterest, .address]
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled, let self else { return }
                let places = response.mapItems.map { MapPlace(mapItem: $0) }
                self.results = places
                self.lastQuery = text
                self.selectedID = nil
                self.isSearching = false
                if places.isEmpty {
                    self.searchError = "No places found for \"\(text)\""
                } else {
                    Haptics.soft()
                    self.frame(places)
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isSearching = false
                self.searchError = "Search failed. Check your connection."
            }
        }
    }

    func quickSearch(_ text: String) {
        Haptics.tap()
        query = text
        runSearch()
    }

    func select(_ place: MapPlace, animated: Bool = true) {
        selectedID = place.id
        let region = MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        if animated {
            withAnimation(Theme.smooth) { cameraPosition = .region(region) }
        } else {
            cameraPosition = .region(region)
        }
        visibleRegion = region
        scheduleThumbnailRefresh()
    }

    /// Called by the view when the map's selection binding changes (marker taps).
    func selectionDidChange() {
        guard let selected else { return }
        Haptics.selection()
        let region = MKCoordinateRegion(center: selected.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        withAnimation(Theme.smooth) { cameraPosition = .region(region) }
        visibleRegion = region
        scheduleThumbnailRefresh()
    }

    func clearSelection() {
        Haptics.tap()
        selectedID = nil
        if !results.isEmpty { frame(results) }
    }

    func clearAll() {
        Haptics.tap()
        searchTask?.cancel()
        query = ""
        lastQuery = ""
        results = []
        selectedID = nil
        isSearching = false
        searchError = nil
    }

    private func frame(_ places: [MapPlace]) {
        guard !places.isEmpty else { return }
        var minLat = places[0].latitude, maxLat = places[0].latitude
        var minLon = places[0].longitude, maxLon = places[0].longitude
        for p in places {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.01)
        )
        let region = MKCoordinateRegion(center: center, span: span)
        withAnimation(Theme.smooth) { cameraPosition = .region(region) }
        visibleRegion = region
        scheduleThumbnailRefresh()
    }

    // MARK: Snapshots & geocoding

    private func scheduleThumbnailRefresh() {
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            let region = self.visibleRegion
            if let image = await self.renderSnapshot(region: region, size: CGSize(width: 360, height: 300)) {
                self.lastSnapshot = image
            }
        }
    }

    private func renderSnapshot(region: MKCoordinateRegion, size: CGSize) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = 1
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.pointOfInterestFilter = .includingAll
        options.showsBuildings = true

        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await MKMapSnapshotter(options: options).start()
        } catch {
            return nil
        }

        let pins = results
        let selectedID = selectedID
        let base = snapshot.image
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: base.size, format: format).image { ctx in
            base.draw(at: .zero)
            let cg = ctx.cgContext
            for place in pins where place.id != selectedID {
                let p = snapshot.point(for: place.coordinate)
                guard base.size.width > p.x, p.x > 0, base.size.height > p.y, p.y > 0 else { continue }
                MapSurfaceModel.drawPin(at: p, radius: 7, color: UIColor(SurfaceKind.maps.tint), in: cg)
            }
            if let selected = pins.first(where: { $0.id == selectedID }) {
                let p = snapshot.point(for: selected.coordinate)
                MapSurfaceModel.drawPin(at: p, radius: 11, color: UIColor(Theme.magenta), in: cg)
            }
        }
    }

    private static func drawPin(at point: CGPoint, radius: CGFloat, color: UIColor, in cg: CGContext) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: UIColor.black.withAlphaComponent(0.5).cgColor)
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: rect)
        cg.setShadow(offset: .zero, blur: 0, color: nil)
        cg.setStrokeColor(UIColor.white.cgColor)
        cg.setLineWidth(2.5)
        cg.strokeEllipse(in: rect)
        cg.setFillColor(UIColor.white.cgColor)
        cg.fillEllipse(in: rect.insetBy(dx: radius * 0.62, dy: radius * 0.62))
    }

    private func regionDescription(for region: MKCoordinateRegion) async -> String {
        if let label = await Self.reverseGeocode(latitude: region.center.latitude, longitude: region.center.longitude, short: true) {
            return label
        }
        return String(format: "%.4f, %.4f", region.center.latitude, region.center.longitude)
    }

    nonisolated static func reverseGeocode(latitude: Double, longitude: Double, short: Bool = false) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        if short {
            let parts = [placemark.locality ?? placemark.subAdministrativeArea, placemark.administrativeArea].compactMap { $0 }
            if !parts.isEmpty { return parts.joined(separator: ", ") }
            return placemark.name
        }
        var parts: [String] = []
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        if !street.isEmpty { parts.append(street) }
        if let locality = placemark.locality { parts.append(locality) }
        let regionLine = [placemark.administrativeArea, placemark.postalCode].compactMap { $0 }.joined(separator: " ")
        if !regionLine.isEmpty { parts.append(regionLine) }
        if parts.isEmpty { return placemark.name }
        return parts.joined(separator: ", ")
    }
}

// MARK: - View

struct MapSurfaceView: View {
    @Bindable var model: MapSurfaceModel
    @FocusState private var searchFocused: Bool
    @State private var scrolledCardID: UUID?

    private let selectedTint = Color(uiColor: .systemRed)

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $model.cameraPosition, selection: $model.selectedID) {
                ForEach(model.results) { place in
                    Marker(place.name, systemImage: place.categorySymbol, coordinate: place.coordinate)
                        .tint(place.id == model.selectedID ? selectedTint : SurfaceKind.maps.tint)
                        .tag(place.id)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.restaurant, .cafe, .hotel, .amusementPark, .airport, .park, .museum, .stadium]), showsTraffic: false))
            .mapControlVisibility(.hidden)
            .onMapCameraChange(frequency: .onEnd) { context in
                model.cameraDidSettle(context.region)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                if model.results.isEmpty && model.lastQuery.isEmpty && !model.isSearching {
                    quickChips
                        .padding(.top, 8)
                }

                Spacer(minLength: 0)

                if let place = model.selected {
                    placeCard(place)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !model.results.isEmpty {
                    resultCards
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let error = model.searchError {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .animation(Theme.snappy, value: model.selectedID)
            .animation(Theme.snappy, value: model.results.count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
        .onChange(of: model.selectedID) { _, newValue in
            model.selectionDidChange()
            if let newValue { scrolledCardID = newValue }
        }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search Maps", text: $model.query)
                .font(.body)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit {
                    Haptics.tap()
                    searchFocused = false
                    model.runSearch()
                }

            if model.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !model.query.isEmpty || !model.results.isEmpty {
                Button {
                    model.clearAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .capsule)
    }

    private var quickChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapSurfaceModel.quickSearches) { item in
                    Chip(title: item.title, symbol: item.symbol) {
                        model.quickSearch(item.title)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
    }

    // MARK: Result cards

    private var resultCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.results) { place in
                    Button {
                        model.select(place)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: place.categorySymbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(SurfaceKind.maps.tint, in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(place.address.isEmpty ? (place.category ?? "Place") : place.address)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(width: 220, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .id(place.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 10)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledCardID)
    }

    // MARK: Place card

    private func placeCard(_ place: MapPlace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: place.categorySymbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(selectedTint, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let category = place.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    model.clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 6) {
                if !place.address.isEmpty {
                    detailRow("mappin.and.ellipse", place.address)
                }
                if let phone = place.phone {
                    detailRow("phone.fill", phone)
                }
                if let url = place.url {
                    detailRow("link", url.host ?? url.absoluteString)
                }
                detailRow("location.north.line", place.coordinateText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func detailRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}
