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
        .package(url: "https://github.com/PerfectlySoft/Perfect-NIO.git", branch: "main"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-CRUD.git", branch: "main"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-MySQL.git", branch: "main"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Logger.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "PerfectNIO",     package: "Perfect-NIO"),
                .product(name: "PerfectNIOCRUD", package: "Perfect-NIO"),
                .product(name: "PerfectCRUD",    package: "Perfect-CRUD"),
                .product(name: "PerfectMySQL",   package: "Perfect-MySQL"),
                .product(name: "PerfectLogger",  package: "Perfect-Logger"),
            ]
        )
    ]
)
