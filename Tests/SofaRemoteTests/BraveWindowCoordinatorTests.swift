import Foundation
import Testing
@testable import SofaRemote

@Suite @MainActor struct BraveWindowCoordinatorTests {
    @Test func existingBraveGetsOneNewWindowOnlyAfterActivation() async throws {
        var front: Int32? = 99
        var waits = 0
        var sent = 0
        try await BraveWindowCoordinator.open(
            launch: { (pid: 42, alreadyRunning: true) },
            frontmostPID: { front }, allowed: { true },
            pause: { waits += 1; front = 42 }, sendNewWindow: { sent += 1 }
        )
        #expect(waits == 1)
        #expect(sent == 1)
    }

    @Test func newBraveUsesItsLaunchWindow() async throws {
        var sent = 0
        try await BraveWindowCoordinator.open(
            launch: { (pid: 42, alreadyRunning: false) }, frontmostPID: { nil },
            allowed: { true }, pause: {}, sendNewWindow: { sent += 1 }
        )
        #expect(sent == 0)
    }

    @Test func noKeyIsSentAfterRevocationOrToAnotherApp() async throws {
        for revoke in [false, true] {
            var authorized = true
            var sent = 0
            do {
                try await BraveWindowCoordinator.open(
                    launch: { (pid: 42, alreadyRunning: true) }, frontmostPID: { 99 },
                    allowed: { authorized }, pause: { if revoke { authorized = false } },
                    sendNewWindow: { sent += 1 }
                )
                Issue.record("Must not send a key when the session is revoked or Brave is not frontmost")
            } catch {}
            #expect(sent == 0)
        }
    }
}
