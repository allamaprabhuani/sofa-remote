import Darwin
import Foundation
import Network
import Testing
@testable import SofaRemote

@Suite @MainActor struct TransportTests {
    private func temporaryFolder() throws -> URL {
        var template = Array("/tmp/sofa-test.XXXXXXXX".utf8CString)
        let pointer = try #require(mkdtemp(&template))
        return URL(fileURLWithPath: String(cString: pointer), isDirectory: true)
    }
    private func request(_ method: String, _ path: String, token: String? = nil, body: [String: Any] = [:]) throws -> HTTPRequest {
        HTTPRequest(method: method, path: path, query: [:], headers: token.map { ["x-sofa-key": $0] } ?? [:],
                    body: try JSONSerialization.data(withJSONObject: body))
    }

    @Test func invitationRoleRevocationExpiryAndRateLimit() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = PairingStore(folder: folder)
        var time = Date(timeIntervalSince1970: 1000)
        var commands = 0
        let server = RemoteServer(store: store, html: { "hi" }, state: { [:] }, route: { _ in commands += 1; return .json(["ok": true]) },
                                  limits: .init(maxConnections: 16, requestSeconds: 9, commandsPerSecond: 1, commandBurst: 2), now: { time })
        let noInvite = try request("POST", "/pair", body: ["code": "123456"])
        #expect(await server.respond(to: noInvite).status == "401 Unauthorized")
        let invitation = server.beginPairing()
        let response = await server.respond(to: try request("POST", "/pair", body: ["code": invitation.code, "name": "Test"]))
        #expect(response.status == "200 OK")
        let json = try #require(try JSONSerialization.jsonObject(with: response.body) as? [String: String])
        let token = try #require(json["token"]), id = try #require(json["deviceID"])
        #expect(token.count == 64 && store.authenticate(token)?.id == id)
        let persisted = try String(contentsOf: folder.appendingPathComponent("paired-devices.json"), encoding: .utf8)
        #expect(!persisted.contains(token))
        let permissions = try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent("paired-devices.json").path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
        let action = try request("POST", "/command", token: token)
        #expect(await server.respond(to: action).status == "200 OK")
        #expect(await server.respond(to: action).status == "200 OK")
        #expect(await server.respond(to: action).status == "429 Too Many Requests")
        time = time.addingTimeInterval(1)
        #expect(await server.respond(to: action).status == "200 OK")
        #expect(commands == 3)
        time = invitation.expires
        #expect(await server.respond(to: try request("POST", "/pair", body: ["code": invitation.code])).status == "401 Unauthorized")
        try store.revoke(id: id)
        #expect(await server.respond(to: action).status == "401 Unauthorized")
    }

    @Test func revocationNotifiesInputOwnerOnlyAfterAuthorization() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = PairingStore(folder: folder)
        let issued = try store.issue(name: "Phone")
        var calls = 0
        let server = RemoteServer(store: store, html: { "" }, state: { [:] }, route: { _ in nil }, onRevoke: { calls += 1 })
        let bad = try request("POST", "/devices/revoke", body: ["id": issued.deviceID])
        #expect(await server.respond(to: bad).status == "401 Unauthorized")
        #expect(calls == 0)
        let good = try request("POST", "/devices/revoke", token: issued.token, body: ["id": issued.deviceID])
        #expect(await server.respond(to: good).status == "200 OK")
        #expect(calls == 1)
        #expect(store.authenticate(issued.token) == nil)
    }

    @Test func maximumPairedDevices() throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = PairingStore(folder: folder)
        for _ in 0..<16 { _ = try store.issue(name: "Phone") }
        #expect(throws: PairingStore.StoreError.self) { try store.issue(name: "Seventeenth") }
    }

    @Test func peerAndOriginBoundaries() {
        for host in ["127.0.0.1", "10.1.2.3", "172.31.1.1", "192.168.1.2", "169.254.2.3", "100.64.3.4", "::1", "fd7a:115c:a1e0::1", "::ffff:192.168.1.2"] {
            #expect(RemotePeer.allowedLiteral(host), "Expected private address: \(host)")
        }
        for host in ["8.8.8.8", "172.32.1.1", "100.128.0.1", "2001:4860:4860::8888", "example.com", "::ffff:8.8.8.8"] {
            #expect(!RemotePeer.allowedLiteral(host), "Expected rejection: \(host)")
        }
        #expect(RemotePeer.validRequestHost(["host": "192.168.1.2:8740", "origin": "http://192.168.1.2:8740"], port: 8740))
        #expect(!RemotePeer.validRequestHost(["host": "evil.example:8740"], port: 8740))
        #expect(!RemotePeer.validRequestHost(["host": "192.168.1.2:8740", "origin": "http://evil.example"], port: 8740))
        #expect(!RemotePeer.validRequestHost(["host": "192.168.1.2:8740", "sec-fetch-site": "cross-site"], port: 8740))
        #expect(!RemotePeer.validRequestHost(["host": "192.168.1.2:8765"], port: 8740))
    }

    @Test func boundedHTTPParsing() {
        let cases = ["GET / HTTP/1.1\r\nBad\r\n\r\n", "POST /pair HTTP/1.1\r\nContent-Length: 65537\r\n\r\n",
                     "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n",
                     "POST / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n"]
        for value in cases {
            if case .invalid = HTTPRequest.parseResult(Data(value.utf8)) {} else { Issue.record("Malformed request accepted") }
        }
        if case .invalid = HTTPRequest.parseResult(Data(repeating: 65, count: 8193)) {} else { Issue.record("Large header accepted") }
        if case .incomplete = HTTPRequest.parseResult(Data("POST / HTTP/1.1\r\nContent-Length: 2\r\n\r\n{".utf8)) {} else { Issue.record("Partial request rejected") }
    }

    @Test func loopbackListenerAndStop() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let server = RemoteServer(store: PairingStore(folder: folder), html: { "sofa-test" }, state: { [:] }, route: { _ in nil })
        defer { server.stop() }
        var port: UInt16?
        server.start(ports: [0]) { port = $0 }
        for _ in 0..<100 where port == nil { try await Task.sleep(for: .milliseconds(20)) }
        let chosen = try #require(port)
        let url = try #require(URL(string: "http://127.0.0.1:\(chosen)/"))
        let (data, response) = try await URLSession.shared.data(from: url)
        #expect(String(data: data, encoding: .utf8) == "sofa-test")
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        server.stop()
        #expect(server.activeConnectionCount == 0)
    }
}
