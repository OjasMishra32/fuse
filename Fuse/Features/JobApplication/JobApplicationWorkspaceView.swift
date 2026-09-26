import SwiftUI

/// A single combined artifact after fusion. Composing always uses the shared StageView.
struct JobApplicationWorkspaceView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.jobCaptureInProgress {
                VStack(spacing: 18) {
                    ProgressView()
                    Text("Combining your résumé and job…").font(.headline)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
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
