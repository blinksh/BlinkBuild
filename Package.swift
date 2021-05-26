// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "BlinkMachines",
  products: [
    .library(name: "Machines", targets: ["Machines"]),
    .library(name: "NonStdIO", targets: ["NonStdIO"]),
    .library(name: "BuildCLI", targets: ["BuildCLI"]),
    .executable(name: "blink-machine", targets: ["CLI"]),
    .executable(name: "build", targets: ["Build"])
  ],
  dependencies: [
//    .package(path: "../Promise"),
    .package(url: "https://github.com/yury/Promise", from: "3.0.0"),
    .package(url: "https://github.com/yury/Spinner", from: "1.3.4"),
    .package(url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.4.0"))
  ],
  targets: [
    .target(
      name: "NonStdIO",
      dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]
    ),
    .target(
      name: "Machines",
      dependencies: ["Promise"]),
    .testTarget(
      name: "MachinesTests",
      dependencies: ["Machines"]),
    .target(
      name: "CLI",
      dependencies: ["Machines", "SwiftCLI", "Spinner"]),
    .target(
      name: "BuildCLI",
      dependencies: [
        "Machines",
        "NonStdIO",
        .product(name: "ArgumentParser", package: "swift-argument-parser")]
    ),
    .target(
      name: "Build",
      dependencies: [
        "BuildCLI"
      ]
    ),
  ]
)
