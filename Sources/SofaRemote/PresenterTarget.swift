import Foundation

/// Classify only the frontmost app. A browser's active tab cannot be identified.
enum PresenterTarget {
    static func classify(_ bundleID: String?) -> String {
        switch bundleID {
        case "com.apple.iWork.Keynote", "com.apple.Keynote": return "keynote"
        case "com.microsoft.Powerpoint": return "powerpoint"
        case "com.apple.Safari", "com.google.Chrome", "com.brave.Browser", "org.mozilla.firefox", "com.microsoft.edgemac": return "browser"
        default: return ""
        }
    }
    static func matches(_ target: String, bundleID: String?) -> Bool {
        !target.isEmpty && ["keynote", "powerpoint", "browser"].contains(target) && classify(bundleID) == target
    }
}
