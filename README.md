# VDStore

[![CI Status](https://img.shields.io/travis/dankinsoid/VDStore.svg?style=flat)](https://travis-ci.org/dankinsoid/VDStore)
[![Version](https://img.shields.io/cocoapods/v/VDStore.svg?style=flat)](https://cocoapods.org/pods/VDStore)
[![License](https://img.shields.io/cocoapods/l/VDStore.svg?style=flat)](https://cocoapods.org/pods/VDStore)
[![Platform](https://img.shields.io/cocoapods/p/VDStore.svg?style=flat)](https://cocoapods.org/pods/VDStore)


## Description
This repository provides

## Example

```swift

```
## Usage

 
## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/VDStore.git", from: "0.0.1")
  ],
  targets: [
    .target(name: "SomeProject", dependencies: ["VDStore"])
  ]
)
```
```ruby
$ swift build
```

2.  [CocoaPods](https://cocoapods.org)

Add the following line to your Podfile:
```ruby
pod 'VDStore'
```
and run `pod update` from the podfile directory first.

## Author

dankinsoid, voidilov@gmail.com

## License

VDStore is available under the MIT license. See the LICENSE file for more info.
