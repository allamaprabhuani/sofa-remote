import Foundation
import Testing
@testable import SofaRemote

@Suite struct WebSocketFrameTests {
    private func frame(_ bytes: [UInt8], opcode: UInt8 = 1) -> Data {
        let key: [UInt8] = [1, 2, 3, 4]
        return Data([0x80 | opcode, 0x80 | UInt8(bytes.count)] + key + bytes.enumerated().map { $0.element ^ key[$0.offset % 4] })
    }
    @Test func maskedFramesAndBounds() {
        let bytes = frame(Array("hello".utf8))
        if case .incomplete = WebSocketFrame.parse(bytes.dropLast()) {} else { Issue.record("Partial frame accepted") }
        if case .frame(let op, let payload, let count) = WebSocketFrame.parse(bytes) {
            #expect(op == 1 && payload == Data("hello".utf8) && count == bytes.count)
        } else { Issue.record("Valid frame rejected") }
        for bad in [Data([0x81, 0]), Data([0x01, 0x80]), Data([0x82, 0x80]), Data([0x81, 0xff]), frame([0xff])] {
            if case .invalid = WebSocketFrame.parse(bad) {} else { Issue.record("Invalid frame accepted") }
        }
    }
    @Test func upgradeRequiresOriginAndProtocol() {
        let headers = ["host": "127.0.0.1:8740", "origin": "http://127.0.0.1:8740", "upgrade": "websocket", "connection": "keep-alive, Upgrade", "sec-websocket-version": "13", "sec-websocket-protocol": "sofa.v1", "sec-websocket-key": "dGhlIHNhbXBsZSBub25jZQ=="]
        func req(_ h: [String: String]) -> HTTPRequest { HTTPRequest(method: "GET", path: "/input", query: [:], headers: h, body: Data()) }
        let response = WebSocketFrame.handshake(req(headers), port: 8740)
        #expect(String(data: response ?? Data(), encoding: .utf8)?.contains("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") == true)
        var bad = headers; bad["origin"] = "http://evil.example"
        #expect(WebSocketFrame.handshake(req(bad), port: 8740) == nil)
        bad = headers; bad.removeValue(forKey: "origin")
        #expect(WebSocketFrame.handshake(req(bad), port: 8740) == nil)
        bad = headers; bad["sec-websocket-protocol"] = "other"
        #expect(WebSocketFrame.handshake(req(bad), port: 8740) == nil)
    }
}
