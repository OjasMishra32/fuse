import SwiftUI

/// A receipt is the proof of submission. This view never turns a completed animation,
/// a successful tailoring response, or a local phase change into an application receipt.
struct JobApplicationView: View {
    @Bindable var session: JobApplicationSession
    var onBack: () -> Void
    var isCompact: Bool
    var onRestart: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDocument: DocumentTab = .resume
    @State private var showCompactDocuments = false

    private enum DocumentTab: String, CaseIterable, Identifiable {
        case resume = "Résumé"
        case letter = "Cover letter"
        case changes = "Changes"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            if isCompact {
                compactContent
            } else {
                openContent
            }
        }
        .background(Theme.grouped)
        .transaction { if reduceMotion { $0.animation = nil } }
        .accessibilityIdentifier("jobApplicationExperience")
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Other demos", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
            .disabled(session.isBusy)
            .accessibilityLabel("Return to other demos")
            .accessibilityIdentifier("jobApplicationBack")
            if session.hasSubmitted, let onRestart {
                Button("New demo application", action: onRestart)
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
            }
            Spacer(minLength: 4)
            Label("FUSE APPLY", systemImage: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.cyan)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.cyan.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, isCompact ? 16 : 24)
        .padding(.vertical, 6)
        .background(Theme.ink)
    }

    private var compactContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                jobHeading
                if session.receipt != nil {
                    receiptCard
                } else {
                    progressCard
                }
                if case .failed(let message) = session.phase { failureCard(message) }
                filledApplication
                if !session.tailoredResume.isEmpty || !session.coverLetter.isEmpty {
                    DisclosureGroup("Your application documents", isExpanded: $showCompactDocuments) {
                        documentTabs.padding(.top, 12)
                        documentContent.padding(.top, 16)
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.accent)
                }
                demoNotice
            }
            .padding(20)
        }
        .accessibilityIdentifier("jobApplicationCompact")
    }

    private var openContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                jobHeading
                Spacer(minLength: 12)
                statusPill
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            GeometryReader { proxy in
                let fold = FoldGeometry.resolve(proxy)
                if fold.isVertical {
                    HStack(spacing: 0) {
                        originalPane.frame(width: max(0, fold.frame.minX))
                        Color.clear.frame(width: max(0, fold.frame.width))
                        applicationPane.frame(width: max(0, proxy.size.width - fold.frame.maxX))
                    }
                } else {
                    VStack(spacing: 0) {
                        originalPane.frame(height: max(0, fold.frame.minY))
                        Color.clear.frame(height: max(0, fold.frame.height))
                        applicationPane.frame(height: max(0, proxy.size.height - fold.frame.maxY))
                    }
                }
            }
        }
        .accessibilityIdentifier("jobApplicationOpenReview")
    }

    private var jobHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(session.company.isEmpty ? "BrightLabs" : session.company)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(session.jobTitle.isEmpty ? "Product Manager, Merchant Growth" : session.jobTitle)
                .font(isCompact ? .title2.bold() : .title3.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("Prepared for \(session.candidateName.isEmpty ? "Alex Morgan" : session.candidateName)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusPill: some View {
        Label(statusTitle, systemImage: session.receipt != nil ? "checkmark.seal.fill" : "doc.text")
            .font(.caption.weight(.semibold))
            .foregroundStyle(session.receipt != nil ? Theme.cyan : Theme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.ink, in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    private var statusTitle: String {
        if session.receipt != nil { return "Receipt confirmed" }
        switch session.phase {
        case .ready: return "Ready to begin"
        case .tailoring: return "Tailoring"
        case .filling: return "Filling application"
        case .submitting: return "Sending application"
        case .submitted: return "Awaiting receipt"
        case .failed: return "Needs attention"
        }
    }

    private var originalPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader("ORIGINAL RÉSUMÉ", subtitle: "Your source stays unchanged", symbol: "doc.text")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if session.originalResume.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Your selected résumé will appear here.").foregroundStyle(.secondary)
                    } else {
                        Text(session.originalResume)
                            .font(.body).lineSpacing(4).textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
        }
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
        .padding(.leading, 12).padding(.trailing, 6).padding(.bottom, 12)
        .accessibilityIdentifier("jobOriginalResume")
    }

    private var applicationPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader("YOUR APPLICATION", subtitle: session.receipt == nil ? "Tailored for this specific role" : "Received by the demo service", symbol: "sparkles")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if session.receipt != nil {
                        openReceiptSummary
                    } else {
                        progressCard
                    }
                    if case .failed(let message) = session.phase { failureCard(message) }
                    filledApplication
                    if !session.tailoredResume.isEmpty || !session.coverLetter.isEmpty {
                        documentTabs
                        documentContent
                    }
                    demoNotice
                }
                .padding(20)
            }
        }
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
        .padding(.leading, 6).padding(.trailing, 12).padding(.bottom, 12)
    }

    private func paneHeader(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption2.weight(.bold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.045))
    }

    private var filledApplication: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "briefcase.fill").foregroundStyle(Theme.violet)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.filledFieldCount == 4 ? "Application filled" : "Your application")
                        .font(.title3.bold())
                    Text("Bright Labs · Merchant Growth").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(session.filledFieldCount)/4").font(.caption.monospacedDigit().bold())
            }
            ProgressView(value: Double(session.filledFieldCount), total: 4).tint(Theme.violet)
            applicationField("Full name", value: session.candidateName, number: 1, symbol: "person")
            applicationField("Email", value: JobApplicationDemo.email, number: 2, symbol: "envelope")
            applicationField("Customized résumé", value: session.tailoredResume, number: 3, symbol: "doc.text")
            applicationField("Cover letter", value: session.coverLetter, number: 4, symbol: "text.alignleft")
            if session.filledFieldCount == 4 {
                Label("Résumé tailored. All application fields completed.", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.cyan)
            }
        }
        .padding(18)
        .background(Theme.violet.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("filledJobApplication")
    }

    private func applicationField(_ title: String, value: String, number: Int, symbol: String) -> some View {
        let complete = session.filledFieldCount >= number
        let active = session.phase == .filling && session.filledFieldCount + 1 == number
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol).font(.caption.weight(.semibold))
                Spacer()
                if complete { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.cyan) }
                else if active { ProgressView().controlSize(.mini) }
            }
            if complete {
                if number > 2 {
                    DisclosureGroup {
                        Text(value).font(.subheadline).lineSpacing(4).textSelection(.enabled)
                    } label: {
                        Text(number == 3 ? "Tailored résumé · View document" : "Personalized cover letter · View")
                            .font(.subheadline.weight(.medium))
                    }.tint(Theme.violet)
                    Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                } else { Text(value).font(.subheadline).textSelection(.enabled) }
            } else {
                Text(active ? "Filling…" : "Waiting for your tailored application")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? Theme.violet : Theme.line, lineWidth: active ? 2 : 1))
        .animation(.easeInOut(duration: 0.25), value: complete)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                if session.isBusy {
                    ProgressView().controlSize(.regular).padding(.top, 4)
                } else {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2).foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(progressTitle).font(.headline)
                    Text(progressDescription).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(spacing: 14) {
                progressStep(number: "1", title: "Tailor résumé + cover letter", detail: "Use the selected job and résumé", complete: !session.tailoredResume.isEmpty, active: isTailoring)
                progressStep(number: "2", title: "Fill application & confirm delivery", detail: "Contact details, résumé, and cover letter", complete: session.receipt != nil, active: isSubmitting || session.phase == .filling)
            }
            if isTailoring {
                Button("Cancel preparation", role: .cancel) { session.cancel() }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("cancelJobPreparation")
            }
            if isSubmitting {
                Text("The request is in progress. A receipt will appear when the service confirms it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Theme.grouped, in: RoundedRectangle(cornerRadius: Theme.radiusCard))
        .accessibilityIdentifier("jobApplicationProgress")
    }

    private var progressTitle: String {
        switch session.phase {
        case .ready: return "A stronger fit starts with your story"
        case .tailoring: return "Finding your most relevant experience"
        case .filling: return "Filling your application"
        case .submitting: return "Your application is filled"
        case .submitted: return "Waiting for the receipt"
        case .failed: return "Your application needs attention"
        }
    }

    private var progressDescription: String {
        switch session.phase {
        case .ready: return "Return to your pair and fold to prepare and submit this fictional application."
        case .tailoring: return "Preparing role-specific wording and a cover letter from your selected résumé."
        case .filling: return "Adding your details, tailored résumé, and cover letter."
        case .submitting: return "Saving it to the local hiring inbox."
        case .submitted: return "Submission is not confirmed until the service returns a receipt."
        case .failed: return "Read the message below. Your source résumé is still here."
        }
    }

    private var isTailoring: Bool {
        if case .tailoring = session.phase { return true }
        return false
    }

    private var isSubmitting: Bool {
        if case .submitting = session.phase { return true }
        return false
    }

    private func progressStep(number: String, title: String, detail: String, complete: Bool, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if complete { Image(systemName: "checkmark").font(.caption.bold()) }
                else { Text(number).font(.caption.bold()) }
            }
            .foregroundStyle(complete || active ? Theme.accent : Theme.textSecondary)
            .frame(width: 28, height: 28)
            .background((complete || active ? Theme.accent : Theme.textSecondary).opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(active ? .semibold : .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number), \(title), \(complete ? "complete" : active ? "in progress" : "waiting")")
    }

    @ViewBuilder private var openReceiptSummary: some View {
        if let receipt = session.receipt {
            VStack(alignment: .leading, spacing: 10) {
                Label("Application received", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(Theme.cyan)
                    .accessibilityIdentifier("applicationReceived")
                Text("Demo service · \(readableDate(receipt.receivedAt))")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("View receipt") { receiptCard.padding(.top, 12) }
                    .font(.caption.weight(.medium)).tint(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder private var receiptCard: some View {
        if let receipt = session.receipt {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 34)).foregroundStyle(Theme.cyan)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application received").font(.title2.bold())
                            .accessibilityIdentifier("applicationReceived")
                        Text("Confirmed by the demo application service")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                receiptRow("Applicant", value: receipt.candidateName)
                receiptRow("Received", value: readableDate(receipt.receivedAt))
                receiptRow("Status", value: receipt.status)
                receiptRow("Receipt", value: receipt.receiptID, monospaced: true)
                DisclosureGroup("Submission details") {
                    VStack(alignment: .leading, spacing: 12) {
                        receiptRow("Application ID", value: receipt.applicationID, monospaced: true)
                        receiptRow("Job ID", value: receipt.jobID, monospaced: true)
                        receiptRow("Destination", value: receipt.destination)
                    }
                    .padding(.top, 12)
                }
                .font(.caption.weight(.medium))
                .tint(Theme.textSecondary)
            }
            .padding(18)
            .background(Theme.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: Theme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard).strokeBorder(Theme.cyan.opacity(0.20)))
            .accessibilityIdentifier("jobApplicationReceipt")
        }
    }

    private func receiptRow(_ title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(monospaced ? .system(.caption, design: .monospaced) : .subheadline.weight(.medium))
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Let's finish this", systemImage: "exclamationmark.circle")
                .font(.headline).foregroundStyle(Theme.magenta)
            Text(message).font(.subheadline).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if session.canRetry {
                Button { session.retry() } label: {
                    Label("Retry", systemImage: "arrow.clockwise").frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("retryJobApplication")
            } else {
                Button(action: onBack) {
                    Label("Return to demos", systemImage: "chevron.left").frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("returnToDemosAfterFailure")
            }
            Text("An application is confirmed only when its receipt appears above.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Theme.magenta.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.radiusCard))
        .accessibilityIdentifier("jobApplicationFailure")
    }

    private var documentTabs: some View {
        Picker("Application document", selection: $selectedDocument) {
            ForEach(DocumentTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("jobApplicationDocumentTabs")
    }

    @ViewBuilder private var documentContent: some View {
        switch selectedDocument {
        case .resume:
            document(session.tailoredResume, title: "Tailored résumé", emptyMessage: "Your tailored résumé is still being prepared.")
        case .letter:
            document(session.coverLetter, title: "Cover letter", emptyMessage: "Your cover letter is still being prepared.")
        case .changes:
            VStack(alignment: .leading, spacing: 20) {
                changeList("What changed", items: session.changes, symbol: "pencil.line", empty: "No change notes were supplied.")
                changeList("Gaps to consider", items: session.gaps, symbol: "text.magnifyingglass", empty: "No gaps were identified in this draft. Review the original job requirements too.")
                Text("Check every factual claim before reusing this draft for a real application.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func document(_ text: String, title: String, emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.headline)
                Spacer(minLength: 8)
                if !text.isEmpty {
                    ShareLink(item: text) {
                        Label("Export", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold))
                    }
                    .accessibilityLabel("Export \(title.lowercased())")
                }
            }
            if text.isEmpty {
                Text(emptyMessage).font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(verbatim: text).font(.body).lineSpacing(4).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func changeList(_ title: String, items: [String], symbol: String, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            if items.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 8)
                        Text(item).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var demoNotice: some View {
        Label("Fictional role and sample candidate. This application goes only to the demo service.", systemImage: "info.circle")
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func readableDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        guard let date else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
