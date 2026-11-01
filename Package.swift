// swift-tools-version:5.10
import PackageDescription
let package = Package(name: "SofaRemote", platforms: [.macOS(.v14)], targets: [
    .executableTarget(name: "SofaRemote"),
    .testTarget(name: "SofaRemoteTests", dependencies: ["SofaRemote"])
])
