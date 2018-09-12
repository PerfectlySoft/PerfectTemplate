// swift-tools-version:4.0

import PackageDescription

let package = Package(
	name: "PerfectTemplate",
	products: [
		.executable(name: "PerfectTemplate", targets: ["PerfectTemplate"])
	],
	dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-SQLite.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Crypto.git", from: "3.0.0")
	],
	targets: [
		.target(name: "PerfectTemplate",
				dependencies: ["PerfectHTTPServer", "PerfectSQLite", "PerfectMustache", "PerfectCrypto"])
	]
)
