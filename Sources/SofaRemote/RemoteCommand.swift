import Foundation
import CoreFoundation

enum RemoteCommand: Equatable {
    enum Button: String { case left, right }
    enum Phase: String { case start, move, end }
    enum HoldPhase: String { case start, heartbeat, end }
    enum Action: String {
        case playPause, previous, next, volumeUp, volumeDown, mute, fullscreen
        case brightnessUp, brightnessDown
        case appSwitcher, spotlight, showDesktop, downloads, lock, screenOff, screenOn, moveWindow
    }
    case move(Double, Double), scroll(Double, Double), click(Button, Int), tap
    case drag(Phase, Double, Double), rightOption(HoldPhase), text(String), key(String, Set<String>), action(Action)

    init(json: [String: Any]) throws {
        func number(_ key: String, optional: Bool = false, limit: Double = 300) throws -> Double {
            if json[key] == nil, optional { return 0 }
            guard let value = json[key] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                  value.doubleValue.isFinite, abs(value.doubleValue) <= limit else {
                throw RemoteError("Motion must be finite and within ±\(Int(limit)).")
            }
            return value.doubleValue
        }
        switch json["type"] as? String {
        case "tap": self = .tap
        case "move": self = .move(try number("dx", limit: 1000), try number("dy", limit: 1000))
        case "scroll": self = .scroll(try number("dx"), try number("dy"))
        case "click":
            guard let button = (json["button"] as? String).flatMap(Button.init(rawValue:)),
                  let count = json["count"] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(),
                  count == 1 || count == 2 else { throw RemoteError("Choose left/right click and a count of 1 or 2.") }
            self = .click(button, count.intValue)
        case "drag":
            guard let phase = (json["phase"] as? String).flatMap(Phase.init(rawValue:)) else { throw RemoteError("Unknown drag phase.") }
            self = .drag(phase, try number("dx", optional: phase != .move, limit: 1000), try number("dy", optional: phase != .move, limit: 1000))
        case "rightOption":
            guard let phase = (json["phase"] as? String).flatMap(HoldPhase.init(rawValue:)) else { throw RemoteError("Unknown key-hold phase.") }
            self = .rightOption(phase)
        case "text":
            guard let value = json["value"] as? String, !value.isEmpty, value.utf16.count <= 2000,
                  value.count <= 1000 else { throw RemoteError("Send between 1 and 1,000 characters at a time.") }
            self = .text(value)
        case "key":
            guard let key = json["key"] as? String, Self.keys.contains(key),
                  let modifiers = json["modifiers"] as? [String], modifiers.count <= 4,
                  modifiers.allSatisfy({ Self.modifiers.contains($0) }) else { throw RemoteError("Unknown key or modifier.") }
            self = .key(key, Set(modifiers))
        case "action":
            guard let action = (json["action"] as? String).flatMap(Action.init(rawValue:)) else { throw RemoteError("Unknown action.") }
            self = .action(action)
        default: throw RemoteError("Unknown input command.")
        }
    }
    static let modifiers: Set<String> = ["command", "control", "option", "shift"]
    static let keys: Set<String> = Set(["enter", "escape", "backspace", "delete", "tab", "space", "up", "down", "left", "right"]
        + Array("abcdefghijklmnopqrstuvwxyz0123456789").map(String.init))
}
