import SwiftUI

// Compatibility cleanup for the previously installed local-employer demo.
// All new pairs, including the sample résumé/job, go through FuseEngine.
extension AppModel {
    func exitJobApplicationWorkspace(clearInstruction: Bool = false) {
        jobDemoActive = false
        jobShowingResult = false
        jobPreviewCover = false
        jobForceInnerPreview = false
        jobCaptureTask?.cancel()
        jobCaptureInProgress = false
        if clearInstruction { instruction = "" }
        resetIntentPreview()
        foldPrompt = false
        foldProgress = 0
    }

    func restartJobDemo() {
        if let scenario = DemoScenario.named("job-application") { apply(scenario) }
    }

    func leaveJobApplication() {
        exitJobApplicationWorkspace(clearInstruction: true)
        left.goHome()
        right.goHome()
    }
}
