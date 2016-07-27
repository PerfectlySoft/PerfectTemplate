# PerfectTemplate

[![Gitter](https://badges.gitter.im/PerfectlySoft/PerfectDocs.svg)](https://gitter.im/PerfectlySoft/PerfectDocs?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Perfect Empty Starter Project

This repository holds a blank Perfect project which can be cloned to serve as a starter for new work. It builds with Swift Package Manager and produces a stand-alone HTTP executable.

**The master branch of this project currently compiles with the default Swift 3.0 toolchain included in Xcode 8 beta 2. On Ubuntu use the *Swift 3.0 Preview 2* toolchain, released July 7th.**

Ensure that you have installed the few dependencies which Perfect requires for your platform:

[Dependencies](https://github.com/PerfectlySoft/Perfect/wiki/Dependencies)

## Issues

We are transitioning to using JIRA for all bugs and support related issues, therefore the GitHub issues has been disabled.

If you find a mistake, bug, or any other helpful suggestion you'd like to make on the docs please head over to [http://jira.perfect.org:8080/servicedesk/customer/portal/1](http://jira.perfect.org:8080/servicedesk/customer/portal/1) and raise it.

A comprehensive list of open issues can be found at [http://jira.perfect.org:8080/projects/ISS/issues](http://jira.perfect.org:8080/projects/ISS/issues)


## Building & Running

The following will clone and build an empty starter project and launch the server on port 8181.

```
git clone https://github.com/PerfectlySoft/PerfectTemplate.git
cd PerfectTemplate
swift build
.build/debug/PerfectTemplate
```

You should see the following output:

```
Starting HTTP server on 0.0.0.0:8181 with document root ./webroot
```

This means the server is running and waiting for connections. Access [http://localhost:8181/](http://127.0.0.1:8181/) to see the greeting. Hit control-c to terminate the server.

## Starter Content

The template file contains a very simple "hello, world!" example.

```swift
import PerfectLib
import PerfectHTTP
import PerfectHTTPServer

// Create HTTP server.
let server = HTTPServer()

// Register your own routes and handlers
var routes = Routes()
routes.add(method: .get, uri: "/", handler: {
		request, response in
		response.appendBody(string: "<html><title>Hello, world!</title><body>Hello, world!</body></html>")
		response.completed()
	}
)

// Add the routes to the server.
server.addRoutes(routes)

// Set a listen port of 8181
server.serverPort = 8181

// Set a document root.
// This is optional. If you do not want to serve static content then do not set this.
// Setting the document root will automatically add a static file handler for the route /**
server.documentRoot = "./webroot"

// Gather command line options and further configure the server.
// Run the server with --help to see the list of supported arguments.
// Command line arguments will supplant any of the values set above.
configureServer(server)

do {
	// Launch the HTTP server.
	try server.start()
} catch PerfectError.networkError(let err, let msg) {
	print("Network error thrown: \(err) \(msg)")
}
```



## Further Information
For more information on the Perfect project, please visit [perfect.org](http://perfect.org).
