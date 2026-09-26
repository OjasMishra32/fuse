import SwiftUI

/// One completed close per observed open; an unprepared close is consumed too.
struct JobApplicationFoldGate {
    private var armed = false
    mutating func observe(closed: Bool, open: Bool, eligible: Bool) -> Bool {
        if open { armed = true }
        guard closed, armed else { return false }
        armed = false
        return eligible
    }
}

extension AppModel {
    var jobCanCombine: Bool {
        jobDemoActive && jobSceneActive && jobWorkspaceVisible && !jobCaptureInProgress
            && jobApplication.phase == .ready && !showSettings && !showScenarios
            && !showInstructionEditor && !showHistory && !showCommunity && !showPaywall
            && !left.isHome && !right.isHome && left.model.hasContent && right.model.hasContent
            && (left.model as? WebSurfaceModel)?.isLoading != true
    }

    func startJobApplication(trigger: FuseTrigger) {
        guard jobCanCombine else { return }
        // Only the demo employer is an automatic destination. Never infer an application URL.
        guard (left.model as? WebSurfaceModel)?.currentURL == JobApplicationDemo.jobURL,
              right.kind == .notes else {
            flash("Use the Bright Labs demo job and fictional résumé for this application.")
            return
        }
        jobCaptureInProgress = true
        lastTrigger = trigger
        Haptics.heavy()
        jobCaptureTask = Task { [weak self] in
            guard let self else { return }
            defer { self.jobCaptureInProgress = false }
            async let job = self.left.model.capture()
            async let resume = self.right.model.capture()
            let (jobInput, resumeInput) = await (job, resume)
            guard !Task.isCancelled, self.jobDemoActive else { return }
            self.jobApplication.start(jobText: jobInput.text, resumeText: resumeInput.text)
        }
    }

    func previewJobCover() {
        guard jobCanCombine else { return }
        startJobApplication(trigger: .demo)
        jobPreviewCover = true
    }

    func restartJobDemo() {
        guard !jobApplication.isBusy, !jobCaptureInProgress else { return }
        jobApplication.reset()
        guard jobApplication.phase == .ready, let scenario = DemoScenario.named("job-application") else { return }
        apply(scenario)
    }

    func leaveJobApplication() {
        guard !jobApplication.isBusy, !jobCaptureInProgress else { return }
        jobDemoActive = false; jobPreviewCover = false; jobForceInnerPreview = false
        left.goHome(); right.goHome()
    }
}
