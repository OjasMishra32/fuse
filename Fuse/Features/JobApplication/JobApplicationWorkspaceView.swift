import SwiftUI

/// A single combined artifact after fusion. Composing always uses the shared StageView.
struct JobApplicationWorkspaceView: View {
    @Bindable var model: AppModel
    @State private var applicationBrowser = WebSurfaceModel()

    var body: some View {
        Group {
            if model.jobCaptureInProgress {
                VStack(spacing: 18) {
                    ProgressView()
                    Text("Combining your résumé and job…").font(.headline)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let receipt = model.jobApplication.receipt {
                WebSurfaceView(model: applicationBrowser)
                    .task(id: receipt.applicationID) {
                        let url = JobApplicationDemo.jobURL.deletingLastPathComponent()
                            .deletingLastPathComponent()
                            .appendingPathComponent("applications")
                            .appendingPathComponent(receipt.applicationID)
                        applicationBrowser.load(url: url)
                    }
            } else {
                JobApplicationView(
                    session: model.jobApplication,
                    onBack: { model.jobShowingResult = false },
                    isCompact: true,
                    onRestart: { model.restartJobDemo() }
                )
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.grouped)
    }
}
