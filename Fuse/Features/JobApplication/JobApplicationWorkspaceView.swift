import SwiftUI

/// The job use case uses the shared app's own browser and Notes surfaces.
struct JobApplicationWorkspaceView: View {
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let divided = !proxy.reservedRegions(kind: .division, options: [.includeInactive]).isEmpty
            let compact = model.jobPreviewCover || (!model.jobForceInnerPreview && !divided && min(proxy.size.width, proxy.size.height) < 600)
            VStack(spacing: 0) {
                if model.jobPreviewCover {
                    HStack {
                        Text("Outer-screen preview · simulator fallback").font(.caption)
                        Spacer()
                        Button("Show inner screens") { model.jobPreviewCover = false; model.jobForceInnerPreview = true }
                    }.padding(12).background(Theme.groupedCard)
                }
                if model.jobApplication.phase == .ready && !model.jobCaptureInProgress {
                    if compact {
                        VStack(spacing: 18) {
                            Image(systemName: "briefcase.fill").font(.largeTitle).foregroundStyle(Theme.violet)
                            Text("Your next chapter").font(.title.bold())
                            Text("Open to review the demo job and résumé.").foregroundStyle(.secondary)
                            #if targetEnvironment(simulator)
                            Button("Preview inner screens") { model.jobForceInnerPreview = true }
                            #endif
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else { composing }
                } else if model.jobCaptureInProgress {
                    ProgressView("Reading your job and résumé…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    JobApplicationView(session: model.jobApplication, onBack: { model.leaveJobApplication() }, isCompact: compact, onRestart: { model.restartJobDemo() })
                        .frame(maxWidth: compact ? 460 : .infinity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Theme.background)
        }
    }

    private var composing: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "briefcase.fill").foregroundStyle(Theme.violet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A job worth the next step.").font(.headline)
                    Text("RÉSUMÉ + JOB → APPLICATION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Spacer()
                HingeBadge(hinge: model.hinge)
                Button("Settings") { model.showSettings = true }
                Button("Other demos") { model.leaveJobApplication() }
            }.padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            GeometryReader { proxy in
                let fold = FoldGeometry.resolve(proxy)
                if fold.isVertical {
                    HStack(spacing: 0) {
                        pane(title: "THE OPPORTUNITY", symbol: "safari", content: model.left.model)
                            .frame(width: max(0, fold.frame.minX))
                        Rectangle().fill(Theme.line).frame(width: max(1, fold.frame.width))
                        pane(title: "YOUR EXPERIENCE", symbol: "note.text", content: model.right.model)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        pane(title: "THE OPPORTUNITY", symbol: "safari", content: model.left.model)
                        Divider()
                        pane(title: "YOUR EXPERIENCE", symbol: "note.text", content: model.right.model)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Close. Your application, filled.").font(.title3.bold())
                        Text("Bright Labs · Product Manager, Merchant Growth").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    #if targetEnvironment(simulator)
                    Button("Preview closed") { model.previewJobCover() }
                        .buttonStyle(.bordered).disabled(!model.jobCanCombine)
                        .accessibilityIdentifier("jobPreviewClosed")
                    #endif
                    Button("Fill my application") { model.startJobApplication(trigger: .seam) }
                        .buttonStyle(.borderedProminent).tint(Theme.violet).disabled(!model.jobCanCombine)
                        .accessibilityIdentifier("applyDemoJob")
                }
                Text("FUSE uses AI to tailor your résumé and fill this application. Sample role · delivery stays in the local demo inbox.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(18).background(Theme.groupedCard)
        }
    }

    private func pane(title: String, symbol: String, content: any SurfaceModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("Inside FUSE").font(.caption2).foregroundStyle(.tertiary)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(Theme.groupedCard)
            SurfaceRegistry.view(for: content).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
