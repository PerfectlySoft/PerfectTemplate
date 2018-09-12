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

import Foundation
import PerfectHTTP
import PerfectHTTPServer
import PerfectMustache
import PerfectCRUD

try TinyURL.initCRUD()

let templatesDir = "./templates"

func addURL(request: HTTPRequest, response: HTTPResponse) {
	do {
		let db = try TinyURL.db()
		let addRequest = try request.decode(AddURLRequest.self)
		return try db.transaction {
			guard let input = try addRequest.validatedInput(db: db) else {
				return response.addHeader(.location, value: "/").completed(status: .found)
			}
			let table = db.table(TinyURL.self)
			try table.insert(input)
			if let children = input.children,
				!children.isEmpty {
				try table.insert(children)
			}
			return response.addHeader(.location, value: "/get/\(input.key)").completed(status: .found)
		}
	} catch {
		return response.setBody(string: "\(error)")
			.completed(status: .internalServerError)
	}
}

func fetchURL(request: HTTPRequest, response: HTTPResponse) {
	guard let key = request.urlVariables["key"] else {
		return response.addHeader(.location, value: "/").completed(status: .found)
	}
	do {
		let db = try TinyURL.db()
		let table = db.table(TinyURL.self)
		guard let found = try table
					.join(\.children, on: \.key, equals: \.parentKey)
					.where(\TinyURL.key == key).first() else {
			return response.addHeader(.location, value: "/").completed(status: .found)
		}
		
		let map = found.dict
		let ctx = MustacheEvaluationContext(templatePath: "\(templatesDir)/display.mustache", map: map)
		let txt = try ctx.formulateResponse(withCollector: MustacheEvaluationOutputCollector())
		response.setBody(string: txt).completed()
	} catch {
		return response.setBody(string: "\(error)")
			.completed(status: .internalServerError)
	}
}

var routes = Routes()
routes.add(uri: "/add", handler: addURL)
routes.add(uri: "/get/{key}", handler: fetchURL)
routes.add(uri: "/**", handler: StaticFileHandler(documentRoot: "./webroot").handleRequest)
try HTTPServer.launch(name: "localhost",
					  port: 8181,
					  routes: routes)
