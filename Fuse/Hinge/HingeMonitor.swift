import SwiftUI

// MARK: - Hinge → AppModel
//
// `onHingeChange` (iOS 27.1) reports the Duo's hinge status and continuous angle. Apple's
// guidance: use the hinge for interactions and effects, and reserved regions for layout.
// We do exactly that — the hinge drives the melt and the trigger; `reservedRegions(.division)`
// tells the stage where the fold physically is.

struct HingeTracking: ViewModifier {
    @Bindable var model: AppModel

    func body(content: Content) -> some View {
        content
            .onHingeChange { old, new in
                model.handleHinge(old: old, new: new)
            }
    }
}

extension View {
    func fuseHingeTracking(_ model: AppModel) -> some View {
        modifier(HingeTracking(model: model))
    }
}

/// Where the fold is, in the coordinate space of the GeometryProxy that asked.
struct FoldGeometry: Equatable {
    var frame: CGRect
    var isActive: Bool
    /// True when the fold runs top→bottom (book pose / flat, left|right panes).
    var isVertical: Bool { frame.height >= frame.width }

    static func resolve(_ proxy: GeometryProxy) -> FoldGeometry {
        let size = proxy.size
        if let region = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first {
            return FoldGeometry(frame: region.frame, isActive: region.isActive)
        }
        // No hinge on this device (or on the cover display): split down the middle of the long side.
        if size.width >= size.height {
            return FoldGeometry(frame: CGRect(x: size.width / 2 - 1, y: 0, width: 2, height: size.height), isActive: false)
        } else {
            return FoldGeometry(frame: CGRect(x: 0, y: size.height / 2 - 1, width: size.width, height: 2), isActive: false)
        }
    }
}

extension DeviceHinge.Status {
    var fuseLabel: String {
        switch self {
        case .closed: "Closed"
        case .partiallyOpen: "Folding"
        case .fullyOpen: "Open"
        default: "Hinge"
        }
    }
}

/// Small, quiet readout of the live hinge angle.
struct HingeBadge: View {
    var hinge: DeviceHinge?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: hinge == nil ? "iphone.slash" : "iphone.gen3")
                .font(.caption2.weight(.medium))
            if let hinge {
                Text("\(Int(hinge.angle.degrees.rounded()))°")
                    .font(.caption.monospacedDigit())
                    .contentTransition(.numericText(value: hinge.angle.degrees))
                Text(hinge.status.fuseLabel)
                    .font(.caption)
            } else {
                Text("No hinge")
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
    }
}
