import Foundation
import CoreFoundation

/// Bounded, allowlisted input for the ephemeral presenter overlay.
struct PresenterCommand {
    enum Action: String { case start, move, end, clear, undo, stop, heartbeat }
    enum Mode: String { case laser, pen }
    let action: Action
    let mode: Mode?
    let display: String?
    let x: Double?
    let y: Double?

    init(json: [String: Any]) throws {
        guard let value = json["action"] as? String, let action = Action(rawValue: value) else {
            throw RemoteError("Choose a presenter action.")
        }
        self.action = action
        if action == .start {
            guard let name = json["mode"] as? String, let mode = Mode(rawValue: name),
                  let display = json["display"] as? String, !display.isEmpty, display.utf8.count <= 128 else {
                throw RemoteError("Choose a connected display and presenter tool.")
            }
            self.mode = mode; self.display = display
        } else { mode = nil; display = nil }
        if action == .start || action == .move {
            func coordinate(_ key: String) throws -> Double {
                guard let n = json[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
                      n.doubleValue.isFinite, (0...1).contains(n.doubleValue) else {
                    throw RemoteError("Presenter coordinates must be between 0 and 1.")
                }
                return n.doubleValue
            }
            x = try coordinate("x"); y = try coordinate("y")
        } else { x = nil; y = nil }
    }
}
