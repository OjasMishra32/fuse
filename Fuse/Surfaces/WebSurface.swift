import SwiftUI
import WebKit
import UIKit
import Observation

// MARK: - Model

@MainActor
@Observable
final class WebSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .web

    /// Text in the address bar. Bound to the text field.
    var addressText: String = ""
    /// True while the text field is focused; navigation finishes won't overwrite what the user types.
    var isEditingAddress: Bool = false

    private(set) var currentURL: URL?
    private(set) var pageTitle: String = ""
    private(set) var progress: Double = 0
    private(set) var isLoading: Bool = false
    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false
    private(set) var lastSnapshot: UIImage?
    private(set) var loadError: String?

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var coordinator: WebNavigationCoordinator?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?

    struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let url: String
    }

    static let suggestions: [Suggestion] = [
        Suggestion(title: "Universal tickets", symbol: "ticket", url: "https://en.wikipedia.org/wiki/Islands_of_Adventure"),
        Suggestion(title: "NYTimes", symbol: "newspaper", url: "https://www.nytimes.com"),
        Suggestion(title: "apple/swift", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com/apple/swift"),
        Suggestion(title: "Wikipedia", symbol: "book", url: "https://en.wikipedia.org/wiki/Special:Random")
    ]

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = UIColor(Theme.ink2)
        wv.scrollView.backgroundColor = UIColor(Theme.ink2)
        wv.allowsBackForwardNavigationGestures = true
        wv.allowsLinkPreview = false
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 27_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.1 Mobile/15E148 Safari/604.1"
        webView = wv

        let coord = WebNavigationCoordinator()
        coord.model = self
        coordinator = coord
        wv.navigationDelegate = coord
        wv.uiDelegate = coord

        // WKWebView KVO always fires on the main thread; the handler type is @Sendable so we assert isolation.
        observations = [
            wv.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.progress = view.estimatedProgress }
            },
            wv.observe(\.title, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.pageTitle = view.title ?? "" }
            },
            wv.observe(\.url, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.currentURL = view.url
                    if !self.isEditingAddress, let url = view.url, url.absoluteString != "about:blank" {
                        self.addressText = url.absoluteString
                    }
                }
            },
            wv.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoBack = view.canGoBack }
            },
            wv.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.canGoForward = view.canGoForward }
            }
        ]
    }

    // MARK: SurfaceModel

    var headline: String {
        if !pageTitle.isEmpty { return pageTitle }
        if let host = currentURL?.host { return host }
        return "Browser"
    }

    var hasContent: Bool {
        guard let url = currentURL else { return false }
        return url.absoluteString != "about:blank"
    }

    var thumbnail: UIImage? { lastSnapshot }

    func capture() async -> SurfaceSnapshot {
        guard hasContent, let url = currentURL else { return .empty(.web) }

        let js = """
        (function(){
          var s = '';
          try { s = (window.getSelection && window.getSelection().toString()) || ''; } catch(e) {}
          var b = '';
          try { b = (document.body && document.body.innerText) || ''; } catch(e) {}
          var hero = '';
          try {
            var og = document.querySelector('meta[property="og:image"], meta[name="og:image"], meta[name="twitter:image"]');
            if (og && og.content) hero = og.content;
            if (!hero) {
              var best = null, bestArea = 40000;
              var imgs = document.images;
              for (var i = 0; i < imgs.length; i++) {
                var im = imgs[i];
                var a = (im.naturalWidth || im.width) * (im.naturalHeight || im.height);
                if (a > bestArea && im.currentSrc && !/logo|icon|sprite|avatar/i.test(im.currentSrc)) { best = im; bestArea = a; }
              }
              if (best) hero = best.currentSrc || best.src;
            }
          } catch(e) {}
          return JSON.stringify({ s: s, b: b, h: hero });
        })()
        """
        let raw = await evaluateString(js)
        var selected = ""
        var bodyText = ""
        var heroURL: URL?
        if let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            selected = (obj["s"] as? String) ?? ""
            bodyText = (obj["b"] as? String) ?? ""
            if let h = obj["h"] as? String, let u = URL(string: h, relativeTo: url)?.absoluteURL, u.scheme?.hasPrefix("http") == true { heroURL = u }
        }
        var hero: UIImage?
        if let heroURL, let (data, _) = try? await URLSession.shared.data(from: heroURL), let img = UIImage(data: data), img.size.width > 120 {
            hero = img.fuseDownscaled(maxEdge: 1024)
        }

        var text = ""
        let sel = selected.fuseCollapsedWhitespace
        if !sel.isEmpty {
            text += "SELECTED: " + sel.fuseClipped(2000) + "\n\n"
        }
        text += bodyText.fuseCollapsedWhitespace.fuseClipped(8000)

        let image = await snapshot(width: 1024)
        if let image { lastSnapshot = image }

        let title = pageTitle.isEmpty ? (url.host ?? url.absoluteString) : pageTitle
        var meta: [String: String] = ["url": url.absoluteString, "title": title]
        if let host = url.host { meta["host"] = host }
        if let heroURL { meta["main_image"] = heroURL.absoluteString }

        return SurfaceSnapshot(kind: .web, title: title, text: text, image: image?.fuseDownscaled(maxEdge: 1024), metadata: meta, heroImage: hero)
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .url(let url): load(url: url)
        case .text(let text): load(query: text)
        case .document(let url): load(url: url)
        case .image, .place: break
        }
    }

    func reset() {
        thumbnailTask?.cancel()
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        currentURL = nil
        pageTitle = ""
        addressText = ""
        progress = 0
        isLoading = false
        lastSnapshot = nil
        loadError = nil
        canGoBack = false
        canGoForward = false
    }

    // MARK: Navigation

    func go() {
        load(query: addressText)
    }

    func load(query: String) {
        guard let url = Self.resolve(query) else { return }
        load(url: url)
    }

    func load(url: URL) {
        var target = url
        if target.scheme == nil, let fixed = URL(string: "https://" + target.absoluteString) {
            target = fixed
        }
        loadError = nil
        isLoading = true
        currentURL = target
        addressText = target.absoluteString
        webView.load(URLRequest(url: target))
    }

    func load(suggestion: Suggestion) {
        Haptics.tap()
        load(query: suggestion.url)
    }

    func reload() { webView.reload() }
    func stop() { webView.stopLoading(); isLoading = false }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }

    /// Turn typed text into a URL. Domains get https://, everything else becomes a Google search.
    static func resolve(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("file://") || lower.hasPrefix("about:") {
            return URL(string: trimmed)
        }

        let hasSpace = trimmed.contains(where: { $0.isWhitespace })
        let hostPart = trimmed.split(separator: "/", maxSplits: 1).first.map(String.init) ?? trimmed
        let looksLikeDomain = !hasSpace
            && hostPart.contains(".")
            && !hostPart.hasPrefix(".")
            && !hostPart.hasSuffix(".")
            && hostPart.split(separator: ".").last.map { $0.count >= 2 && $0.allSatisfy { $0.isLetter || $0.isNumber } } == true
        let isLocalhost = !hasSpace && (lower.hasPrefix("localhost") || lower.hasPrefix("127.0.0.1"))

        if looksLikeDomain || isLocalhost {
            let scheme = isLocalhost ? "http://" : "https://"
            if let url = URL(string: scheme + trimmed) { return url }
        }

        var comps = URLComponents(string: "https://www.google.com/search")
        comps?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        return comps?.url
    }

    // MARK: Delegate hooks

    fileprivate func navigationDidStart() {
        isLoading = true
        loadError = nil
    }

    fileprivate func navigationDidFinish() {
        isLoading = false
        progress = 1
        pageTitle = webView.title ?? pageTitle
        currentURL = webView.url ?? currentURL
        if !isEditingAddress, let url = webView.url, url.absoluteString != "about:blank" {
            addressText = url.absoluteString
        }
        scheduleThumbnailRefresh()
    }

    fileprivate func navigationDidFail(_ error: Error) {
        isLoading = false
        let ns = error as NSError
        // Cancelled navigations (redirects, user typed a new URL) are not failures.
        guard !(ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled) else { return }
        guard !(ns.domain == "WebKitErrorDomain" && ns.code == 102) else { return } // frame load interrupted by policy change
        loadError = ns.localizedDescription
    }

    // MARK: Snapshots

    private func scheduleThumbnailRefresh() {
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            if let image = await self.snapshot(width: 480) {
                self.lastSnapshot = image
            }
        }
    }

    private func snapshot(width: CGFloat) async -> UIImage? {
        guard webView.bounds.width > 0, webView.bounds.height > 0 else { return nil }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = NSNumber(value: Double(width))
        config.afterScreenUpdates = true
        let view = webView
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            view.takeSnapshot(with: config) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func evaluateString(_ js: String) async -> String {
        let view = webView
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            view.evaluateJavaScript(js) { result, _ in
                continuation.resume(returning: (result as? String) ?? "")
            }
        }
    }
}

// MARK: - WebKit delegate

@MainActor
private final class WebNavigationCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var model: WebSurfaceModel?

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        model?.navigationDidStart()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        model?.navigationDidFinish()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        model?.navigationDidFail(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        model?.navigationDidFail(error)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // Keep everything inside the surface; never bounce out to Safari or other apps.
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
           !["http", "https", "about", "file", "data", "blob"].contains(scheme) {
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target="_blank" links open in the same web view.
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - Representable

private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - View

struct WebSurfaceView: View {
    @Bindable var model: WebSurfaceModel
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            addressBar
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 6)

            ZStack {
                Theme.ink2

                if model.hasContent {
                    WebViewContainer(webView: model.webView)
                } else {
                    emptyState
                }

                if let error = model.loadError, !model.isLoading {
                    errorBanner(error)
                }
            }
            .ignoresSafeArea(edges: [.bottom, .horizontal])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
        .onChange(of: addressFocused) { _, focused in
            model.isEditingAddress = focused
            if !focused, let url = model.currentURL, model.hasContent {
                model.addressText = url.absoluteString
            }
        }
    }

    // MARK: Address bar

    private var addressBar: some View {
        HStack(spacing: 6) {
            GlassIconButton(symbol: "chevron.left", size: 32, tint: model.canGoBack ? Theme.textPrimary : Theme.textTertiary) {
                Haptics.tap()
                model.goBack()
            }
            .disabled(!model.canGoBack)

            GlassIconButton(symbol: "chevron.right", size: 32, tint: model.canGoForward ? Theme.textPrimary : Theme.textTertiary) {
                Haptics.tap()
                model.goForward()
            }
            .disabled(!model.canGoForward)

            addressField
        }
    }

    private var addressField: some View {
        HStack(spacing: 8) {
            Image(systemName: leadingSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(model.currentURL?.scheme == "https" ? Theme.mint : Theme.textTertiary)

            TextField("Search or enter URL", text: $model.addressText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.cyan)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit {
                    Haptics.tap()
                    addressFocused = false
                    model.go()
                }
                .lineLimit(1)
                .truncationMode(.tail)

            if addressFocused && !model.addressText.isEmpty {
                Button {
                    model.addressText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            } else if model.isLoading {
                Button {
                    model.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            } else if model.hasContent {
                Button {
                    Haptics.tap()
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Haptics.tap()
                    addressFocused = false
                    model.go()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(model.addressText.isEmpty ? Theme.textTertiary : Theme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(model.addressText.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .capsule)
        .overlay(alignment: .bottom) {
            if model.isLoading {
                GeometryReader { geo in
                    Capsule()
                        .fill(Theme.energy)
                        .frame(width: max(8, geo.size.width * CGFloat(min(max(model.progress, 0.04), 1))), height: 2)
                        .animation(Theme.smooth, value: model.progress)
                }
                .frame(height: 2)
                .padding(.horizontal, 14)
                .offset(y: -3)
            }
        }
    }

    private var leadingSymbol: String {
        if model.isLoading { return "globe" }
        guard let url = model.currentURL, model.hasContent else { return "magnifyingglass" }
        return url.scheme == "https" ? "lock.fill" : "globe"
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            SurfaceEmptyState(
                symbol: "safari",
                title: "Open a page",
                hint: "Search or paste a link above, then fold to fuse it with the other screen.",
                tint: SurfaceKind.web.tint
            )
            .frame(maxHeight: 220)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(WebSurfaceModel.suggestions) { suggestion in
                    Chip(title: suggestion.title, symbol: suggestion.symbol, tint: SurfaceKind.web.tint) {
                        model.load(suggestion: suggestion)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.magenta)
                Text(message)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button("Retry") {
                    Haptics.tap()
                    model.reload()
                }
                .font(.fuseCaption)
                .foregroundStyle(Theme.cyan)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .padding(12)
        }
    }
}
