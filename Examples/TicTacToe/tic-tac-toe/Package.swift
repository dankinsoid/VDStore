// swift-tools-version:5.9

import PackageDescription

let package = Package(
	name: "tic-tac-toe",
	platforms: [
		.iOS(.v17),
	],
	products: [
		.library(name: "AppCore", targets: ["AppCore"]),
		.library(name: "AppSwiftUI", targets: ["AppSwiftUI"]),
		.library(name: "AppUIKit", targets: ["AppUIKit"]),
		.library(name: "AuthenticationClient", targets: ["AuthenticationClient"]),
		.library(name: "GameCore", targets: ["GameCore"]),
		.library(name: "GameSwiftUI", targets: ["GameSwiftUI"]),
		.library(name: "GameUIKit", targets: ["GameUIKit"]),
		.library(name: "LoginCore", targets: ["LoginCore"]),
		.library(name: "LoginSwiftUI", targets: ["LoginSwiftUI"]),
		.library(name: "LoginUIKit", targets: ["LoginUIKit"]),
		.library(name: "NewGameCore", targets: ["NewGameCore"]),
		.library(name: "NewGameSwiftUI", targets: ["NewGameSwiftUI"]),
		.library(name: "NewGameUIKit", targets: ["NewGameUIKit"]),
		.library(name: "TwoFactorCore", targets: ["TwoFactorCore"]),
		.library(name: "TwoFactorSwiftUI", targets: ["TwoFactorSwiftUI"]),
		.library(name: "TwoFactorUIKit", targets: ["TwoFactorUIKit"]),
	],
	dependencies: [
		.package(name: "VDStore", path: "../../.."),
		.package(url: "https://github.com/dankinsoid/VDFlow.git", from: "4.26.0"),
	],
	targets: [
		.target(
			name: "AppCore",
			dependencies: [
				"AuthenticationClient",
				"LoginCore",
				"NewGameCore",
				"VDStore",
				"VDFlow",
			]
		),
		.testTarget(
			name: "AppCoreTests",
			dependencies: ["AppCore"]
		),
		.target(
			name: "AppSwiftUI",
			dependencies: [
				"AppCore",
				"LoginSwiftUI",
				"NewGameSwiftUI",
			]
		),
		.target(
			name: "AppUIKit",
			dependencies: [
				"AppCore",
				"LoginUIKit",
				"NewGameUIKit",
			]
		),

		.target(
			name: "AuthenticationClient",
			dependencies: ["VDStore"]
		),
		.target(
			name: "GameCore",
			dependencies: ["VDStore", "VDFlow"]
		),
		.testTarget(
			name: "GameCoreTests",
			dependencies: ["GameCore"]
		),
		.target(
			name: "GameSwiftUI",
			dependencies: ["GameCore"]
		),
		.target(
			name: "GameUIKit",
			dependencies: ["GameCore"]
		),

		.target(
			name: "LoginCore",
			dependencies: [
				"AuthenticationClient",
				"TwoFactorCore",
				"VDStore",
				"VDFlow",
			]
		),
		.testTarget(
			name: "LoginCoreTests",
			dependencies: ["LoginCore"]
		),
		.target(
			name: "LoginSwiftUI",
			dependencies: [
				"LoginCore",
				"TwoFactorSwiftUI",
			]
		),
		.target(
			name: "LoginUIKit",
			dependencies: [
				"LoginCore",
				"TwoFactorUIKit",
			]
		),

		.target(
			name: "NewGameCore",
			dependencies: [
				"GameCore",
				"VDStore",
				"VDFlow",
			]
		),
		.testTarget(
			name: "NewGameCoreTests",
			dependencies: ["NewGameCore"]
		),
		.target(
			name: "NewGameSwiftUI",
			dependencies: [
				"GameSwiftUI",
				"NewGameCore",
			]
		),
		.target(
			name: "NewGameUIKit",
			dependencies: [
				"GameUIKit",
				"NewGameCore",
			]
		),

		.target(
			name: "TwoFactorCore",
			dependencies: [
				"AuthenticationClient",
				"VDStore",
				"VDFlow",
			]
		),
		.testTarget(
			name: "TwoFactorCoreTests",
			dependencies: ["TwoFactorCore"]
		),
		.target(
			name: "TwoFactorSwiftUI",
			dependencies: ["TwoFactorCore"]
		),
		.target(
			name: "TwoFactorUIKit",
			dependencies: ["TwoFactorCore"]
		),
	]
)

for target in package.targets {
	target.swiftSettings = [
		.unsafeFlags([
			"-Xfrontend", "-enable-actor-data-race-checks",
			"-Xfrontend", "-warn-concurrency",
		]),
	]
}
