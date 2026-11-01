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

    @Test func presenterEndpointRequiresPairingAndSharesCommandRateLimit() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let store = PairingStore(folder: folder)
        let phone = try store.issue(name: "Phone")
        var calls = 0
        let server = RemoteServer(store: store, html: { "" }, state: { [:] }, route: { _ in
            calls += 1; return .json(["ok": true])
        }, limits: .init(maxConnections: 16, requestSeconds: 9, commandsPerSecond: 0, commandBurst: 2))
        #expect(await server.respond(to: try request("POST", "/presenter")).status == "401 Unauthorized")
        #expect(await server.respond(to: try request("POST", "/presenter", token: phone.token)).status == "200 OK")
        #expect(await server.respond(to: try request("POST", "/command", token: phone.token)).status == "200 OK")
        #expect(await server.respond(to: try request("POST", "/presenter", token: phone.token)).status == "429 Too Many Requests")
        #expect(calls == 2)
        try store.revoke(id: phone.deviceID)
        #expect(await server.respond(to: try request("POST", "/presenter", token: phone.token)).status == "401 Unauthorized")
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

    @Test func publicIconsAreFixedAssetsAndManifestUsesPNG() async throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at: folder) }
        let image = Data([137, 80, 78, 71])
        let server = RemoteServer(store: PairingStore(folder: folder), html: { "" }, state: { [:] }, route: { _ in nil },
                                  icons: ["/icon-180.png": image, "/private.png": image])
        let icon = await server.respond(to: try request("GET", "/icon-180.png"))
        #expect(icon.contentType == "image/png" && icon.body == image)
        #expect(await server.respond(to: try request("GET", "/icon-512.png")).status == "404 Not Found")
        #expect(await server.respond(to: try request("GET", "/private.png")).status == "401 Unauthorized")
        let manifest = await server.respond(to: try request("GET", "/manifest.webmanifest"))
        let json = try #require(try JSONSerialization.jsonObject(with: manifest.body) as? [String: Any])
        let icons = try #require(json["icons"] as? [[String: String]])
        #expect(icons.map { $0["src"] } == ["/icon-192.png", "/icon-512.png"])
        #expect(RemotePage.html.contains("rel=\"apple-touch-icon\""))
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
        let navigation = ["host": "192.168.1.2:8740", "sec-fetch-site": "cross-site", "sec-fetch-mode": "navigate", "sec-fetch-dest": "document"]
        #expect(RemotePeer.validRequestHost(navigation, port: 8740, allowDocumentNavigation: true))
        #expect(!RemotePeer.validRequestHost(navigation, port: 8740)) // API routes never opt in.
        var frame = navigation; frame["sec-fetch-dest"] = "iframe"
        #expect(!RemotePeer.validRequestHost(frame, port: 8740, allowDocumentNavigation: true))
        var fetch = navigation; fetch["sec-fetch-mode"] = "cors"
        #expect(!RemotePeer.validRequestHost(fetch, port: 8740, allowDocumentNavigation: true))
        var wrongOrigin = navigation; wrongOrigin["origin"] = "http://evil.example"
        #expect(!RemotePeer.validRequestHost(wrongOrigin, port: 8740, allowDocumentNavigation: true))
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
        let headers = try #require(response as? HTTPURLResponse)
        #expect(headers.value(forHTTPHeaderField: "X-Frame-Options") == "DENY")
        #expect(headers.value(forHTTPHeaderField: "Content-Security-Policy")?.contains("frame-ancestors 'none'") == true)
        #expect(headers.value(forHTTPHeaderField: "Referrer-Policy") == "no-referrer")
        server.stop()
        #expect(server.activeConnectionCount == 0)
    }
}
