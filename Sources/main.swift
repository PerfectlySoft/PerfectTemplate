//
//  main.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 2015-11-05.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer

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
    response.completed()
}

do {
    
    // Launch the HTTP server on port 8181
    try HTTPServer(documentRoot: webRoot).start(port: 8181)
    
} catch PerfectError.networkError(let err, let msg) {
    print("Network error thrown: \(err) \(msg)")
}
