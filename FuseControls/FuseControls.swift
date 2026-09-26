import WidgetKit
import SwiftUI
import AppIntents

@main
struct FuseControlsBundle: WidgetBundle {
    var body: some Widget {
        FuseControl()
    }
}

/// The "Fuse" button in Control Center and on the Lock Screen: one tap from any app.
struct FuseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.ojasvamishra.fuse.control") {
            ControlWidgetButton(action: FuseControlIntent()) {
                Label("Fuse", systemImage: "circle.hexagongrid.fill")
            }
        }
        .displayName("Fuse")
        .description("Fuse what you were just doing.")
    }
}
