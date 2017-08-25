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

struct Filter404: HTTPResponseFilter {
  func filterBody(response: HTTPResponse, callback: (HTTPResponseFilterResult) -> ()) {
    callback(.continue)
  }

  func filterHeaders(response: HTTPResponse, callback: (HTTPResponseFilterResult) -> ()) {
    if case .notFound = response.status {
      response.setBody(string: "404 \(response.request.path)")
      response.setHeader(.contentLength, value: "\(response.bodyBytes.count)")
      callback(.done)
    } else {
      callback(.continue)
    }
  }
}

public func filter404(data: [String:Any]) throws -> HTTPResponseFilter {
  return Filter404()
}

let confData = [
	"servers": [
		[
			"name":"localhost",
			"port":8181,
			"routes":[
				["method":"get", "uri":"/**", "handler":PerfectHTTPServer.HTTPHandler.staticFiles,
				 "documentRoot":"./webroot",
				 "allowResponseFilters":true]
			],
			"filters":[
				[
				"type":"response",
				"priority":"high",
				"name": filter404,
				]
			]
		]
	]
]

do {
	// Launch the servers based on the configuration data.
	try HTTPServer.launch(configurationData: confData)
} catch {
	fatalError("\(error)") // fatal error launching one of the servers
}

