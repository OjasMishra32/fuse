import SwiftUI
import UIKit

// MARK: - The floating orb
//
// Fuse while you use other apps. The orb floats over Safari (or anything else); it shows
// the two pages you're reading, and its button fuses them in the background. The inputs
// come from the Safari extension's recents, so nothing has to be captured or opened.

extension AppModel {
    func attachOrb() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return }
        let orb = FloatingOrb.shared
        orb.attach(to: window)
        orb.statusProvider = { [weak self] in self?.orbStatus() ?? ("Fuse", "") }
        orb.onTrigger = { [weak self] in self?.fuseFromOrb() }
        orb.onRestore = { [weak self] in
            guard let self else { return }
            if let result = self.currentResult, self.phase != .result { self.open(result) }
        }
    }

    /// What the orb says while idle: the two most recent pages, or how to get them.
    func orbStatus() -> (String, String) {
        if phase == .fusing { return ("Fusing", "Working…") }
        if phase == .result, let r = currentResult { return (r.title, r.summary) }
        let visits = SharedInbox.recentVisits().filter { Date().timeIntervalSince($0.at) < 45 * 60 }
        switch visits.count {
        case 0: return ("Fuse", "Read two pages in Safari")
        case 1: return ("One page", visits[0].title)
        default: return ("Fuse these two", "\(visits[0].title) + \(visits[1].title)")
        }
    }

    /// Fuse the last two pages from Safari without bringing Fuse to the front.
    func fuseFromOrb() {
        let orb = FloatingOrb.shared
        guard phase != .fusing else { return }
        let visits = SharedInbox.recentVisits().filter { Date().timeIntervalSince($0.at) < 45 * 60 }
        guard visits.count >= 2 else {
            orb.show("Not yet", detail: "Read two pages in Safari, then tap ⏸")
            return
        }
        let a = visits[0], b = visits[1]
        let left = SurfaceSnapshot(kind: .web, title: a.title, text: (a.selection.isEmpty ? "" : "SELECTED: \(a.selection)\n\n") + a.text, metadata: ["url": a.url])
        let right = SurfaceSnapshot(kind: .web, title: b.title, text: (b.selection.isEmpty ? "" : "SELECTED: \(b.selection)\n\n") + b.text, metadata: ["url": b.url])

        // Mirror into the halves so the app matches the orb when it comes back.
        if let ua = URL(string: a.url) { self.left.apply(.url(ua), as: .web) }
        if let ub = URL(string: b.url) { self.right.apply(.url(ub), as: .web) }

        phase = .fusing
        fusingStage = FuseEngine.Stage.reading.rawValue
        fusingStartedAt = Date()
        orb.show("Fusing", detail: "\(a.title) + \(b.title)", busy: true)

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await FuseEngine().fuse(left: left, right: right, instruction: nil) { stage in
                    Task { @MainActor in
                        self.fusingStage = stage.rawValue
                        orb.show("Fusing", detail: stage.rawValue, busy: true)
                    }
                }
                self.currentResult = result
                self.instruction = ""
                withAnimation(Theme.smooth) { self.phase = .result }
                HistoryStore.shared.add(result)
                RevenueCatService.shared.recordFuse()
                SharedInbox.clearRecents()
                orb.show(result.title, detail: result.summary)
                Haptics.success()
            } catch {
                withAnimation(Theme.smooth) { self.phase = .compose }
                orb.show("Couldn't fuse", detail: error.localizedDescription)
            }
        }
    }
}
