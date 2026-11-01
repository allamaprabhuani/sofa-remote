import Foundation
import Darwin
import Network

/// The remote accepts loopback, private/link-local, and Tailscale IP peers only.
enum RemotePeer {
    static func allowed(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let value): return allowedLiteral(String(describing: value))
        case .ipv6(let value): return allowedLiteral(String(describing: value))
        default: return false
        }
    }

    static func allowedLiteral(_ input: String) -> Bool {
        let value = String(input.split(separator: "%", maxSplits: 1).first ?? "")
        var v4 = in_addr()
        if value.withCString({ inet_pton(AF_INET, $0, &v4) }) == 1 {
            let b = withUnsafeBytes(of: v4) { Array($0) }
            return b[0] == 10 || b[0] == 127 || (b[0] == 192 && b[1] == 168) ||
                (b[0] == 172 && (16...31).contains(b[1])) || (b[0] == 169 && b[1] == 254) ||
                (b[0] == 100 && (64...127).contains(b[1]))
        }
        var v6 = in6_addr()
        if value.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 {
            let b = withUnsafeBytes(of: v6) { Array($0) }
            if b[0..<10].allSatisfy({ $0 == 0 }) && b[10] == 255 && b[11] == 255 {
                return allowedLiteral("\(b[12]).\(b[13]).\(b[14]).\(b[15])")
            }
            return (b[0..<15].allSatisfy { $0 == 0 } && b[15] == 1) ||
                (b[0] & 0xfe == 0xfc) || (b[0] == 0xfe && b[1] & 0xc0 == 0x80)
        }
        return false
    }

    /// Reject DNS-rebinding names and mismatched cross-origin browser requests.
    static func validRequestHost(_ headers: [String: String], port: UInt16) -> Bool {
        guard let host = headers["host"], host.utf8.count < 256,
              let url = URLComponents(string: "http://" + host), url.user == nil, url.password == nil,
              url.path.isEmpty, url.query == nil, url.fragment == nil,
              let hostname = url.host, hostname == "localhost" || allowedLiteral(hostname.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))),
              (url.port ?? 80) == Int(port) else { return false }
        if let site = headers["sec-fetch-site"], site.lowercased() != "same-origin" && site.lowercased() != "none" { return false }
        if let origin = headers["origin"] {
            guard let value = URLComponents(string: origin), value.scheme == "http", value.user == nil, value.password == nil,
                  value.host?.lowercased() == hostname.lowercased(), (value.port ?? 80) == (url.port ?? 80),
                  value.path.isEmpty, value.query == nil, value.fragment == nil else { return false }
        }
        return true
    }
}
