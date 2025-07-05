// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
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
		.package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"601.0.0-prerelease"),
	],
	targets: [
		.target(name: "VDStore", dependencies: ["VDStoreMacros"]),
		.macro(
			name: "VDStoreMacros",
			dependencies: [
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
			]
		),
		.target(name: "VDStoreTestUtils", dependencies: ["VDStore"]),
		.testTarget(name: "VDStoreTests", dependencies: ["VDStoreTestUtils"]),
	]
)
