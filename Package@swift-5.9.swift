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
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.2"),
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
		.testTarget(name: "VDStoreTests", dependencies: ["VDStore"]),
	]
)
