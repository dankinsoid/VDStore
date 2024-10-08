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
		.library(name: "VDStoreTestUtils", targets: ["VDStoreTestUtils"]),
	],
	dependencies: [
	],
	targets: [
		.target(name: "VDStore", dependencies: []),
		.target(name: "VDStoreTestUtils", dependencies: ["VDStore"]),
		.testTarget(name: "VDStoreTests", dependencies: ["VDStoreTestUtils"]),
	]
)
