import Foundation
import Darwin

enum NetworkAddresses {
    static func links(port: UInt16) -> [(label: String, address: String)] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let start = first else { return [] }
        defer { freeifaddrs(first) }
        var addresses: [(String, String)] = []
        for entry in sequence(first: start, next: { $0.pointee.ifa_next }) {
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  Int32(entry.pointee.ifa_flags) & IFF_UP != 0 else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            var value = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &value, socklen_t(value.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ip = String(cString: value)
            if name.hasPrefix("en") || name.hasPrefix("utun") { addresses.append((name, ip)) }
        }
        var links: [(String, String)] = []
        if let lan = addresses.first(where: { $0.0 == "en0" }) ?? addresses.first(where: { $0.0.hasPrefix("en") }) {
            links.append(("Same Wi-Fi", "http://\(lan.1):\(port)"))
        }
        if let tail = addresses.first(where: { pair in
            let octets = pair.1.split(separator: ".").compactMap { Int($0) }
            return pair.0.hasPrefix("utun") && octets.count == 4 && octets[0] == 100 && (64...127).contains(octets[1])
        }) { links.append(("Tailscale", "http://\(tail.1):\(port)")) }
        return links
    }
}
