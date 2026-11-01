import Foundation
import CryptoKit

/// Minimal RFC 6455 framing for bounded, unfragmented client messages.
enum WebSocketFrame {
    enum Result { case incomplete, invalid, frame(UInt8, Data, Int) }
    static func parse(_ data: Data) -> Result {
        let b = [UInt8](data)
        guard b.count >= 2 else { return .incomplete }
        let opcode = b[0] & 0x0f
        guard b[0] & 0xf0 == 0x80, [1, 8, 9, 10].contains(opcode), b[1] & 0x80 != 0 else { return .invalid }
        var length = Int(b[1] & 0x7f), offset = 2
        if length == 126 {
            guard b.count >= 4 else { return .incomplete }
            length = Int(b[2]) << 8 | Int(b[3]); offset = 4
            guard length >= 126 else { return .invalid }
        } else if length == 127 { return .invalid }
        guard length <= 4096, opcode == 1 || length <= 125, opcode != 8 || length != 1 else { return .invalid }
        guard b.count >= offset + 4 + length else { return .incomplete }
        let mask = Array(b[offset..<offset + 4]); offset += 4
        let payload = Data((0..<length).map { b[offset + $0] ^ mask[$0 % 4] })
        if opcode == 1 && String(data: payload, encoding: .utf8) == nil { return .invalid }
        return .frame(opcode, payload, offset + length)
    }
    static func encode(_ opcode: UInt8, _ payload: Data) -> Data {
        var result = Data([0x80 | opcode])
        if payload.count < 126 { result.append(UInt8(payload.count)) }
        else { result.append(126); result.append(UInt8((payload.count >> 8) & 255)); result.append(UInt8(payload.count & 255)) }
        result.append(payload); return result
    }
    static func handshake(_ request: HTTPRequest, port: UInt16) -> Data? {
        let h = request.headers
        guard request.method == "GET", request.path == "/input", request.query.isEmpty, request.body.isEmpty,
              h["origin"] != nil, RemotePeer.validRequestHost(h, port: port),
              h["upgrade"]?.lowercased() == "websocket",
              h["connection"]?.lowercased().split(separator: ",").contains(where: { $0.trimmingCharacters(in: .whitespaces) == "upgrade" }) == true,
              h["sec-websocket-version"] == "13",
              h["sec-websocket-protocol"]?.split(separator: ",").contains(where: { $0.trimmingCharacters(in: .whitespaces) == "sofa.v1" }) == true,
              let key = h["sec-websocket-key"], let decoded = Data(base64Encoded: key), decoded.count == 16 else { return nil }
        let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
        let accept = Data(digest).base64EncodedString()
        return Data("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\nSec-WebSocket-Protocol: sofa.v1\r\n\r\n".utf8)
    }
}
