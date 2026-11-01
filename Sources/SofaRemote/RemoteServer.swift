import Foundation
import Network

/// A bounded LAN HTTP listener. Direct HTTP does not encrypt the pairing code or device token.
@MainActor
final class RemoteServer {
    struct Limits {
        var maxConnections = 16
        var requestSeconds: TimeInterval = 9
        var commandsPerSecond: Double = 90
        var commandBurst: Double = 120
    }
    typealias Route = @MainActor (HTTPRequest) async -> HTTPResponse?
    @MainActor private final class Client {
        let connection: NWConnection
        var timer: DispatchWorkItem?
        var task: Task<Void, Never>?
        var requestStarted = Date()
        var reading = false
        var responding = false
        init(_ connection: NWConnection) { self.connection = connection }
    }
    private let store: PairingStore
    private let html: () -> String
    private let state: @MainActor () -> [String: Any]
    private let route: Route
    private let onRevoke: @MainActor () -> Void
    private let icons: [String: Data]
    private let limits: Limits
    private let now: () -> Date
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var failedAttempts: [Date] = []
    private struct Bucket { var tokens: Double; var updated: Date }
    private var buckets: [String: Bucket] = [:]
    private(set) var port: UInt16?
    private(set) var pairingCode: String?
    private(set) var pairingExpires: Date?
    private var stopped = false
    var activeConnectionCount: Int { clients.count }

    init(store: PairingStore, html: @escaping () -> String,
         state: @escaping @MainActor () -> [String: Any], route: @escaping Route,
         limits: Limits = Limits(), now: @escaping () -> Date = Date.init,
         onRevoke: @escaping @MainActor () -> Void = {}, icons: [String: Data] = AppIcons.images) {
        self.store = store; self.html = html; self.state = state; self.route = route; self.onRevoke = onRevoke
        self.limits = limits; self.now = now
        self.icons = icons
    }

    @discardableResult
    func beginPairing() -> (code: String, expires: Date) {
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        let expires = now().addingTimeInterval(300)
        pairingCode = code; pairingExpires = expires
        failedAttempts.removeAll()
        return (code, expires)
    }
    func endPairing() { pairingCode = nil; pairingExpires = nil }

    func start(ports: [UInt16] = Array(8740...8749), onReady: @escaping @MainActor (UInt16) -> Void) {
        guard !stopped, listener == nil, let first = ports.first else { return }
        do {
            let listener: NWListener
            if first == 0 { listener = try NWListener(using: .tcp) }
            else {
                guard let endpoint = NWEndpoint.Port(rawValue: first) else { return }
                listener = try NWListener(using: .tcp, on: endpoint)
            }
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated {
                    guard let self else { connection.cancel(); return }
                    self.accept(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                MainActor.assumeIsolated {
                    guard let self, !self.stopped else { listener?.cancel(); return }
                    switch state {
                    case .ready:
                        guard let actual = listener?.port?.rawValue else { listener?.cancel(); return }
                        self.port = actual; onReady(actual)
                    case .failed:
                        listener?.cancel()
                        if self.listener === listener { self.listener = nil }
                        self.start(ports: Array(ports.dropFirst()), onReady: onReady)
                    default: break
                    }
                }
            }
            self.listener = listener
            listener.start(queue: .main)
        } catch { start(ports: Array(ports.dropFirst()), onReady: onReady) }
    }

    func stop() {
        stopped = true
        endPairing()
        listener?.stateUpdateHandler = nil; listener?.newConnectionHandler = nil
        listener?.cancel(); listener = nil; port = nil
        let active = Array(clients.values); clients.removeAll()
        for client in active { client.timer?.cancel(); client.task?.cancel(); client.connection.cancel() }
        buckets.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        guard !stopped, clients.count < limits.maxConnections, RemotePeer.allowed(connection.endpoint) else {
            connection.cancel(); return
        }
        let client = Client(connection)
        clients[ObjectIdentifier(connection)] = client
        connection.start(queue: .main)
        read(client, buffer: Data())
    }
    private func discard(_ client: Client) {
        client.timer?.cancel(); client.task?.cancel()
        clients.removeValue(forKey: ObjectIdentifier(client.connection))
        client.connection.cancel()
    }
    private func armDeadline(_ client: Client) {
        client.timer?.cancel()
        let remaining = max(0, limits.requestSeconds - Date().timeIntervalSince(client.requestStarted))
        let timer = DispatchWorkItem { [weak self, weak client] in
            guard let self, let client else { return }
            MainActor.assumeIsolated { self.discard(client) }
        }
        client.timer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: timer)
    }
    private func read(_ client: Client, buffer: Data) {
        guard !stopped, !client.reading, clients[ObjectIdentifier(client.connection)] != nil else { return }
        armDeadline(client)
        client.reading = true
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024) { [weak self, weak client] data, _, complete, error in
            MainActor.assumeIsolated {
                guard let self, let client, self.clients[ObjectIdentifier(client.connection)] != nil else { return }
                client.reading = false
                if client.responding {
                    // A peer disconnect or a pipelined request cancels its outstanding route.
                    if complete || error != nil || !(data?.isEmpty ?? true) { self.discard(client) }
                    else { self.read(client, buffer: Data()) }
                    return
                }
                var buffer = buffer
                if let data { buffer.append(data) }
                switch HTTPRequest.parseResult(buffer) {
                case .incomplete:
                    if complete || error != nil { self.discard(client) }
                    else { self.read(client, buffer: buffer) }
                case .invalid(let status):
                    self.send(.json(["error": "Invalid request"], status: status), to: client)
                case .complete(let request, let consumed):
                    guard !complete, error == nil, consumed == buffer.count, let port = self.port,
                          RemotePeer.validRequestHost(request.headers, port: port,
                                                      allowDocumentNavigation: request.method == "GET" && request.path == "/"),
                          request.method != "POST" || request.headers["content-type"]?.lowercased().split(separator: ";").first == "application/json" else {
                        self.send(.json(["error": "Request origin or content type not allowed"], status: "403 Forbidden"), to: client); return
                    }
                    client.responding = true
                    self.read(client, buffer: Data()) // Observe disconnects during the asynchronous route.
                    client.task = Task { @MainActor [weak self, weak client] in
                        guard let self, let client else { return }
                        let response = await self.respond(to: request)
                        guard !Task.isCancelled, self.clients[ObjectIdentifier(client.connection)] != nil else { return }
                        self.send(response, to: client, keepAlive: request.keepAlive)
                    }
                }
            }
        }
    }
    private func send(_ response: HTTPResponse, to client: Client, keepAlive: Bool = false) {
        client.connection.send(content: response.serialized(keepAlive: keepAlive), completion: .contentProcessed { [weak self, weak client] error in
            MainActor.assumeIsolated {
                guard let self, let client, self.clients[ObjectIdentifier(client.connection)] != nil else { return }
                if !keepAlive || error != nil { self.discard(client) }
                else {
                    client.task = nil
                    client.responding = false
                    client.requestStarted = Date()
                    self.armDeadline(client)
                    if !client.reading { self.read(client, buffer: Data()) }
                }
            }
        })
    }

    func respond(to request: HTTPRequest) async -> HTTPResponse {
        if request.method == "GET", request.path == "/" {
            return HTTPResponse(contentType: "text/html; charset=utf-8", body: Data(html().utf8))
        }
        if request.method == "GET", request.path == "/manifest.webmanifest" {
            var response = HTTPResponse.json(["name": "Sofa Remote", "short_name": "Sofa", "start_url": "/", "display": "standalone", "icons": [192, 512].map { ["src": "/icon-\($0).png", "sizes": "\($0)x\($0)", "type": "image/png"] }])
            response.contentType = "application/manifest+json"; return response
        }
        if request.method == "GET", AppIcons.paths.contains(request.path) {
            guard let data = icons[request.path] else { return .json(["error": "Icon is unavailable in this build."], status: "404 Not Found") }
            return HTTPResponse(contentType: "image/png", body: data)
        }
        if request.method == "GET", request.path == "/icon.svg" {
            let icon = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><rect width=\"64\" height=\"64\" rx=\"16\" fill=\"#20232b\"/><rect x=\"12\" y=\"18\" width=\"40\" height=\"28\" rx=\"6\" fill=\"#8caaff\"/></svg>"
            return HTTPResponse(contentType: "image/svg+xml", body: Data(icon.utf8))
        }
        if request.method == "POST", request.path == "/pair" {
            failedAttempts.removeAll { now().timeIntervalSince($0) >= 60 }
            guard failedAttempts.count < 10 else { return .json(["error": "Too many attempts. Try again shortly."], status: "429 Too Many Requests") }
            guard let expiry = pairingExpires, now() < expiry, let code = pairingCode,
                  let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  object["code"] as? String == code else {
                failedAttempts.append(now())
                return .json(["error": "Pairing is closed or the code is incorrect."], status: "401 Unauthorized")
            }
            do {
                let issued = try store.issue(name: object["name"] as? String ?? "Phone")
                return .json(["token": issued.token, "deviceID": issued.deviceID])
            } catch PairingStore.StoreError.deviceLimit {
                return .json(["error": "Device limit reached. Revoke a device before pairing."], status: "409 Conflict")
            } catch { return .json(["error": "Could not save the paired device."], status: "500 Internal Server Error") }
        }
        guard let device = store.authenticate(request.headers["x-sofa-key"]) else {
            return .json(["error": "Pair with the Mac first."], status: "401 Unauthorized")
        }
        if request.method == "POST", request.path == "/command", !consumeCommand(device.id) {
            return .json(["error": "Too many commands. Try again shortly."], status: "429 Too Many Requests")
        }
        switch (request.method, request.path) {
        case ("GET", "/state"): return .json(state())
        case ("GET", "/devices"):
            return .json(store.activeDevices().map { ["id": $0.id, "name": $0.name, "current": $0.id == device.id] as [String: Any] })
        case ("POST", "/devices/revoke"):
            guard let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any], let id = body["id"] as? String else {
                return .json(["error": "Choose a device."], status: "400 Bad Request")
            }
            do {
                try store.revoke(id: id)
                onRevoke()
                return .json(["ok": true])
            }
            catch { return .json(["error": "Could not revoke the device."], status: "500 Internal Server Error") }
        default: return await route(request) ?? .json(["error": "Not found"], status: "404 Not Found")
        }
    }

    private func consumeCommand(_ deviceID: String) -> Bool {
        let timestamp = now()
        var bucket = buckets[deviceID] ?? Bucket(tokens: limits.commandBurst, updated: timestamp)
        bucket.tokens = min(limits.commandBurst, bucket.tokens + max(0, timestamp.timeIntervalSince(bucket.updated)) * limits.commandsPerSecond)
        bucket.updated = timestamp
        guard bucket.tokens >= 1 else { buckets[deviceID] = bucket; return false }
        bucket.tokens -= 1
        buckets[deviceID] = bucket
        return true
    }
}

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data
    var keepAlive: Bool { headers["connection"]?.lowercased() != "close" }
    enum ParseResult { case incomplete, invalid(String), complete(HTTPRequest, Int) }
    static func parse(_ data: Data) -> (HTTPRequest, Int)? {
        if case .complete(let request, let count) = parseResult(data) { return (request, count) }
        return nil
    }
    static func parseResult(_ data: Data) -> ParseResult {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else {
            return data.count > 8192 ? .invalid("431 Request Header Fields Too Large") : .incomplete
        }
        guard end.upperBound <= 8192, let head = String(data: data[..<end.lowerBound], encoding: .utf8) else { return .invalid("431 Request Header Fields Too Large") }
        var lines = head.components(separatedBy: "\r\n")
        let parts = lines.removeFirst().split(separator: " ")
        guard parts.count == 3, ["GET", "POST"].contains(String(parts[0])), parts[1].hasPrefix("/"),
              ["HTTP/1.1", "HTTP/1.0"].contains(String(parts[2])) else { return .invalid("400 Bad Request") }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":"), colon != line.startIndex else { return .invalid("400 Bad Request") }
            let name = line[..<colon].lowercased()
            guard headers[name] == nil else { return .invalid("400 Bad Request") }
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["transfer-encoding"] == nil, let length = Int(headers["content-length"] ?? "0"), length >= 0 else { return .invalid("400 Bad Request") }
        guard length <= 65536 else { return .invalid("413 Payload Too Large") }
        guard data.count - end.upperBound >= length else { return .incomplete }
        guard let url = URLComponents(string: String(parts[1])), url.host == nil else { return .invalid("400 Bad Request") }
        var query: [String: String] = [:]; url.queryItems?.forEach { query[$0.name] = $0.value ?? "" }
        return .complete(HTTPRequest(method: String(parts[0]), path: url.path, query: query, headers: headers,
                                     body: data.subdata(in: end.upperBound..<end.upperBound + length)), end.upperBound + length)
    }
}

struct HTTPResponse {
    var status = "200 OK"
    var contentType = "application/json"
    var body = Data()
    static func json(_ value: Any, status: String = "200 OK") -> HTTPResponse {
        HTTPResponse(status: status, body: (try? JSONSerialization.data(withJSONObject: value)) ?? Data())
    }
    func serialized(keepAlive: Bool = false) -> Data {
        Data("HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nContent-Security-Policy: frame-ancestors 'none'; base-uri 'none'; object-src 'none'\r\nReferrer-Policy: no-referrer\r\nConnection: \(keepAlive ? "keep-alive" : "close")\r\n\r\n".utf8) + body
    }
}
