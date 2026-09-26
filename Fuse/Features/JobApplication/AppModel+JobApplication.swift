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
    /// Only the complete sample pair opts into automatic application delivery.
    /// Match the actual browser location and complete source text, never a keyword or headline.
    var jobApplicationPair: (job: WebSurfaceModel, resume: NotesSurfaceModel)? {
        guard !left.isHome, !right.isHome else { return nil }
        for (jobModel, resumeModel) in [(left.model, right.model), (right.model, left.model)] {
            guard let job = jobModel as? WebSurfaceModel,
                  let resume = resumeModel as? NotesSurfaceModel,
                  job.currentURL == JobApplicationDemo.jobURL,
                  JobApplicationDemo.normalize(resume.text) == JobApplicationDemo.normalize(JobApplicationDemo.resume)
            else { continue }
            return (job, resume)
        }
        return nil
    }

    func activateJobApplicationIfRecognized() {
        guard !jobDemoActive, phase == .compose, jobApplicationPair != nil else { return }
        jobDemoActive = true
        jobPreviewCover = false; jobForceInnerPreview = false
        jobFoldGate = JobApplicationFoldGate()
        if let hinge, hinge.status == .fullyOpen || hinge.angle.degrees > 120 {
            _ = jobFoldGate.observe(closed: false, open: true, eligible: false)
        }
        chosenSuggestion = nil; instruction = ""; foldPrompt = false; foldProgress = 0
        FloatingOrb.shared.dismiss()
        // A previous receipt belongs to this sample and remains available until Start again.
    }

    var jobCanCombine: Bool {
        jobDemoActive && jobSceneActive && jobWorkspaceVisible && !jobCaptureInProgress
            && jobApplication.phase == .ready && !showSettings && !showScenarios
            && !showInstructionEditor && !showHistory && !showCommunity && !showPaywall
            && jobApplicationPair != nil && jobApplicationPair?.job.isLoading == false
    }

    func startJobApplication(trigger: FuseTrigger) {
        guard jobCanCombine else { return }
        // Only the demo employer is an automatic destination. Never infer an application URL.
        guard let pair = jobApplicationPair else {
            flash("Use the Bright Labs demo job and fictional résumé for this application.")
            return
        }
        jobCaptureInProgress = true
        lastTrigger = trigger
        Haptics.heavy()
        jobCaptureTask = Task { [weak self] in
            guard let self else { return }
            defer { self.jobCaptureInProgress = false }
            async let job = pair.job.capture()
            async let resume = pair.resume.capture()
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
