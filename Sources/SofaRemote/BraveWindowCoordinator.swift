import Foundation

/// Waits for the requested app to be frontmost before delivering a new-window key.
@MainActor enum BraveWindowCoordinator {
    static func open(
        launch: () async throws -> (pid: Int32, alreadyRunning: Bool),
        frontmostPID: () -> Int32?,
        allowed: () -> Bool,
        pause: () async throws -> Void = { try await Task.sleep(nanoseconds: 100_000_000) },
        sendNewWindow: () throws -> Void
    ) async throws {
        guard allowed() else { throw RemoteError("Input paused or connection ended. Reconnect and try again.") }
        let app = try await launch()
        guard allowed() else { throw RemoteError("Input paused or connection ended. Reconnect and try again.") }
        // A newly launched Brave creates its own window. Existing instances need Command-N.
        guard app.alreadyRunning else { return }
        for _ in 0..<20 {
            guard allowed() else { throw RemoteError("Input paused or connection ended. Reconnect and try again.") }
            if frontmostPID() == app.pid {
                try sendNewWindow()
                return
            }
            try await pause()
        }
        throw RemoteError("Brave did not become active. Open it on the Mac and try again.")
    }
}
