// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerfectTemplate",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "PerfectTemplate", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-NIO.git", from: "0.1.0"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-CRUD.git", from: "3.1.0"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-MySQL.git", from: "4.0.0"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Logger.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "PerfectNIO",     package: "Perfect-NIO"),
                .product(name: "PerfectCRUD",    package: "Perfect-CRUD"),
                .product(name: "PerfectMySQL",   package: "Perfect-MySQL"),
                .product(name: "PerfectLogger",  package: "Perfect-Logger"),
                .product(name: "NIOPosix",       package: "swift-nio"),
            ]
        )
    ]
)
