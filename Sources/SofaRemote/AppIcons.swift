import Foundation

enum AppIcons {
    static let paths = ["/icon-180.png", "/icon-192.png", "/icon-512.png"]
    // Load the three fixed bundled assets once; never resolve a caller-supplied file path.
    static let images: [String: Data] = Dictionary(uniqueKeysWithValues: paths.compactMap { path in
        let name = String(path.dropFirst().dropLast(4))
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (path, data)
    })
}
