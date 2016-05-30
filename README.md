# PerfectTemplate
Perfect Empty Starter Project

This repository holds a blank Perfect project which can be cloned to serve as a starter for new work. It builds with Swift Package Manager and produces a stand-alone HTTP executable.

```swift
import PerfectLib

// Initialize base-level services
PerfectServer.initializeServices()

// Create our webroot
// This will serve all static content by default
let webRoot = "./webroot"
try Dir(webRoot).create()

// Add our routes and such
// Register your own routes and handlers
Routing.Routes["/"] = {
    request, response in
    
    response.appendBody(string: "<html><title>Hello, world!</title><body>Hello, world!</body></html>")
    response.requestCompleted()
}

do {
    
    // Launch the HTTP server on port 8181
    try HTTPServer(documentRoot: webRoot).start(port: 8181)
    
} catch PerfectError.NetworkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}
```
