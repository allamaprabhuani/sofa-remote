import Foundation
import CoreFoundation

enum RemoteCommand: Equatable {
    enum Button: String { case left, right }
    enum Phase: String { case start, move, end }
    enum Action: String {
        case playPause, previous, next, volumeUp, volumeDown, mute, fullscreen
        case appSwitcher, spotlight, showDesktop, downloads, lock, screenOff, screenOn, moveWindow
    }
    case move(Double, Double), scroll(Double, Double), click(Button, Int)
    case drag(Phase, Double, Double), text(String), key(String, Set<String>), action(Action)

    init(json: [String: Any]) throws {
        func number(_ key: String, optional: Bool = false) throws -> Double {
            if json[key] == nil, optional { return 0 }
            guard let value = json[key] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                  value.doubleValue.isFinite, abs(value.doubleValue) <= 300 else {
                throw RemoteError("Motion must be a finite value between −300 and 300.")
            }
            return value.doubleValue
        }
        switch json["type"] as? String {
        case "move": self = .move(try number("dx"), try number("dy"))
        case "scroll": self = .scroll(try number("dx"), try number("dy"))
        case "click":
            guard let button = (json["button"] as? String).flatMap(Button.init(rawValue:)),
                  let count = json["count"] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(),
                  count == 1 || count == 2 else { throw RemoteError("Choose left/right click and a count of 1 or 2.") }
            self = .click(button, count.intValue)
        case "drag":
            guard let phase = (json["phase"] as? String).flatMap(Phase.init(rawValue:)) else { throw RemoteError("Unknown drag phase.") }
            self = .drag(phase, try number("dx", optional: phase != .move), try number("dy", optional: phase != .move))
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
