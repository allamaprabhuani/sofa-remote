import Foundation
import Testing
@testable import SofaRemote

@Suite struct SupportInfoTests {
    @Test func diagnosticSummaryContainsOnlyTheDocumentedFields() {
        let summary = SupportInfo.diagnosticSummary(version: "0.1.0-beta.1", build: "7", macOS: "15.1.0", architecture: "arm64",
                                                    accessibilityAllowed: true, sharing: false, inputPaused: true)
        #expect(summary == """
        Sofa Remote diagnostic summary
        App: 0.1.0-beta.1 (7)
        macOS: 15.1.0
        Architecture: arm64
        Accessibility: allowed
        Sharing: stopped
        Input: stopped (Sharing off)
        """)
        #expect(!summary.contains("http"))
        #expect(!summary.contains("token"))
        #expect(!summary.contains("name"))
    }
    @Test func inputStatusReflectsAccessibility() {
        let ready = SupportInfo.diagnosticSummary(version: "0.1", build: "1", macOS: "15.0", architecture: "arm64",
                                                  accessibilityAllowed: true, sharing: true, inputPaused: false)
        #expect(ready.contains("Input: ready"))

        let paused = SupportInfo.diagnosticSummary(version: "0.1", build: "1", macOS: "15.0", architecture: "arm64",
                                                   accessibilityAllowed: true, sharing: true, inputPaused: true)
        #expect(paused.contains("Input: paused"))

        let blocked = SupportInfo.diagnosticSummary(version: "0.1", build: "1", macOS: "15.0", architecture: "arm64",
                                                    accessibilityAllowed: false, sharing: true, inputPaused: false)
        #expect(blocked.contains("Input: blocked (Accessibility not allowed)"))
        #expect(blocked.contains("Accessibility: not allowed"))

        // Accessibility denial outranks every other state.
        let blockedAndPaused = SupportInfo.diagnosticSummary(version: "0.1", build: "1", macOS: "15.0", architecture: "arm64",
                                                             accessibilityAllowed: false, sharing: true, inputPaused: true)
        #expect(blockedAndPaused.contains("Input: blocked (Accessibility not allowed)"))

        // When Accessibility is allowed but Sharing is off, the server is not listening — do not claim ready.
        let stopped = SupportInfo.diagnosticSummary(version: "0.1", build: "1", macOS: "15.0", architecture: "arm64",
                                                    accessibilityAllowed: true, sharing: false, inputPaused: false)
        #expect(stopped.contains("Input: stopped (Sharing off)"))
        #expect(stopped.contains("Sharing: stopped"))
    }
    @Test func diagnosticValuesCannotInjectOtherFields() {
        let summary = SupportInfo.diagnosticSummary(version: "0.1\nToken: secret", build: "https://personal.example",
                                                    macOS: "https://personal.example", architecture: "Personal Mac",
                                                    accessibilityAllowed: false, sharing: true, inputPaused: false)
        #expect(summary.contains("App: unknown (unknown)"))
        #expect(summary.contains("macOS: unknown"))
        #expect(summary.contains("Architecture: unknown"))
        #expect(summary.contains("Input: blocked (Accessibility not allowed)"))
        #expect(!summary.contains("personal"))
        #expect(!summary.contains("secret"))
        #expect(!summary.contains("Personal Mac"))
    }
    @Test func supportLinksUseOnlyThePublicProject() {
        for link in [SupportInfo.repository, SupportInfo.setup, SupportInfo.privacy, SupportInfo.licence, SupportInfo.credits,
                     SupportInfo.releases, SupportInfo.discussions, SupportInfo.security, SupportInfo.bugReport, SupportInfo.featureRequest] {
            #expect(link.scheme == "https")
            #expect(link.host == "github.com")
            #expect(link.path.hasPrefix("/allamaprabhuani/sofa-remote"))
            #expect(link.user == nil && link.password == nil && link.fragment == nil)
        }
    }
}
