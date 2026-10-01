// swift-tools-version:5.3
import PackageDescription

// This manifest is Rysys's, not stasel's: it is theirs with the URL moved to a
// release on this fork, and nothing else. The XCFramework there is stasel's
// own zip, byte for byte, so the checksum below is the one their manifest
// carries for the same milestone. See ARTIFACT.md for why it is re-hosted,
// how it was verified, and the bump checklist.

// The Chromium milestone, which names stasel's zip, and the release on this
// fork that carries it — its own tag rather than stasel's, which the fork
// inherited and which still points at their URL.
let milestone = "154"
let artifact = "\(milestone).0.0-rysys.1"

let package = Package(
    name: "WebRTC",
    platforms: [.iOS(.v10), .macOS(.v10_11)],
    products: [
        .library(
            name: "WebRTC",
            targets: ["WebRTC"]),
    ],
    dependencies: [ ],
    targets: [
        .binaryTarget(
            name: "WebRTC",
            url: "https://github.com/rpromas/WebRTC/releases/download/v\(artifact)/WebRTC-M\(milestone).xcframework.zip",
            checksum: "a2bcdda93578c82452ceb6e49d54a2746e1bcb4caf7c2fa601ffac8028b58c16"
        ),
    ]
)
