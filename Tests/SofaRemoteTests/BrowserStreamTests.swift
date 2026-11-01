import Foundation
import Darwin
import Testing
@testable import SofaRemote

@Suite @MainActor struct BrowserStreamTests {
    @Test func realBrowserStreamsToNativeListener() async throws {
        var template = Array("/tmp/sofa-browser-test.XXXXXXXX".utf8CString)
        let pointer = try #require(mkdtemp(&template))
        let folder = URL(fileURLWithPath: String(cString: pointer), isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PairingStore(folder: folder)
        let issued = try store.issue(name: "Disposable browser test")
        var commands: [(String, String?, Date)] = []
        var httpCommands = 0, disconnects = 0
        let server = RemoteServer(store: store, html: { RemotePage.html }, state: {
            ["name": "Test Mac", "sharing": true, "accessibility": true, "sessionLocked": false,
             "screenSleeping": false, "displays": [["id": "d1", "name": "Test"]],
             "displayID": "d1", "shortcuts": [], "keepAwake": false]
        }, route: { request in
            guard request.method == "POST", request.path == "/command",
                  let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let type = object["type"] as? String else { return nil }
            if request.headers["host"] != nil { httpCommands += 1 }
            commands.append((type, object["phase"] as? String, Date()))
            return .json(["ok": true])
        }, onRevoke: { disconnects += 1 })
        defer { server.stop() }
        var port: UInt16?
        server.start(ports: [0]) { port = $0 }
        for _ in 0..<100 where port == nil { try await Task.sleep(for: .milliseconds(20)) }
        let chosen = try #require(port)
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let result = await Self.runBrowser(repository: repository, port: chosen, token: issued.token)
        if result.status == 77 || result.status == 127 {
            print("SKIP live browser stream: Node 22+ or Chrome/Brave is unavailable")
            return
        }
        #expect(result.status == 0, "Browser integration failed (exit \(result.status))")
        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let summary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Browser did not return a JSON summary"); return
        }
        for _ in 0..<100 where disconnects == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(summary["streamReady"] as? Bool == true)
        #expect(summary["httpCommands"] as? Int == 0 && httpCommands == 0)
        #expect(summary["dragStartSent"] as? Bool == true && summary["dragEndSent"] as? Bool == true)
        #expect(commands.filter { $0.0 == "move" || ($0.0 == "drag" && $0.1 == "move") }.count >= 40)
        let phases = commands.filter { $0.0 == "drag" }.compactMap { $0.1 }
        #expect(phases.first == "start" && phases.last == "end")
        #expect(disconnects > 0)
        let moves = commands.filter { $0.0 == "move" || ($0.0 == "drag" && $0.1 == "move") }.map { $0.2 }
        let gaps = zip(moves.dropFirst(), moves).map { $0.timeIntervalSince($1) * 1000 }.sorted()
        let median = gaps.isEmpty ? 0 : gaps[gaps.count / 2]
        print("Live browser stream: \(moves.count) moves, median gap \(String(format: "%.1f", median)) ms, max gap \(String(format: "%.1f", gaps.last ?? 0)) ms; \(httpCommands) HTTP command fallbacks")
    }

    // Waiting for the child occurs off the main actor, which must serve the listener.
    private nonisolated static func runBrowser(repository: URL, port: UInt16, token: String) async -> (status: Int32, output: String) {
        await Task.detached {
            let process = Process(), pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["node", "Tests/Web/live-stream.test.cjs"]
            process.currentDirectoryURL = repository
            var environment = ProcessInfo.processInfo.environment
            environment["SOFA_TEST_PORT"] = String(port); environment["SOFA_TEST_TOKEN"] = token
            process.environment = environment
            process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return (127, "") }
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 45, execute: timeout)
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit(); timeout.cancel()
            return (process.terminationStatus, String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        }.value
    }
}
