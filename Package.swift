// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "VDStore",
	platforms: [
		.iOS(.v13),
		.macOS(.v10_15),
		.tvOS(.v13),
		.watchOS(.v6),
	],
	products: [
		.library(name: "VDStore", targets: ["VDStore"]),
	],
	dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.2.2")
	],
	targets: [
		.target(
            name: "VDStore",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
		.testTarget(name: "VDStoreTests", dependencies: ["VDStore"]),
	]
)
