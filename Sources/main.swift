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

// Add our routes and such
// Register your own routes and handlers
Routing.Routes["/"] = {
	request, response in

	response.appendBody(string: "<html><title>Hello, world!</title><body>Hello, world!</body></html>")
	response.completed()
}

do {
	let server = HTTPServer()
	
	// Set a listen port of 8181
	server.serverPort = 8181
	
	// Set a document root.
	// This is optional. If you do not want to serve static content then do not set this.
	server.documentRoot = "./webroot"
	
	// Gather command line options and further configure the server.
	// Run the server with --help to see the list of supported arguments.
	// Command line arguments will supplant any of the values set above.
	configureServer(server)
	
	// Launch the HTTP server.
	try server.start()
    
} catch PerfectError.networkError(let err, let msg) {
	print("Network error thrown: \(err) \(msg)")
}
