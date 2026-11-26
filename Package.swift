// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "OhMyHeadroom",
  // Liquid Glass (glassEffect, glassProminent) exists from macOS 26 on.
  platforms: [.macOS("26.0")],
  targets: [
    .executableTarget(
      name: "OhMyHeadroom",
      path: "Sources/OhMyHeadroom",
      resources: [.copy("Fonts")]
    )
  ]
)
