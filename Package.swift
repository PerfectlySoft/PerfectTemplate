import PackageDescription
#if os(Linux)
import Glibc
#else
import Darwin
#endif

var url = "https://github.com/PerfectlySoft/Perfect-HTTPServer.git"
if let urlenv = getenv("URL_PERFECT_HTTPSERVER") {
	url = String(cString: urlenv)
}

let package = Package(
	name: "PerfectTemplate",
	targets: [],
	dependencies: [
		.Package(url: url, majorVersion: 3),
	]
)
