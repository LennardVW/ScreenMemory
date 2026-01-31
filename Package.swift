// swift-tools-version:6.0
// ScreenMemory - Searchable screenshot history with OCR

import PackageDescription

let package = Package(
    name: "ScreenMemory",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "screenmemory", targets: ["ScreenMemory"])],
    targets: [.executableTarget(name: "ScreenMemory", swiftSettings: [.swiftLanguageMode(.v6)])]
)
