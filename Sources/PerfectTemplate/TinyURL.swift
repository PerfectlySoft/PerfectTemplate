//
//  TinyURL.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 2018-09-09.
//

import Foundation
import PerfectSQLite
import PerfectCRUD
import PerfectCrypto

let databaseName = "/tmp/tinyurl.db"
typealias DatabaseType = Database<SQLiteDatabaseConfiguration>

struct TinyURL: Codable {
	let key: String
	let parentKey: String
	let destination: URL?
	let description: String?
	let children: [TinyURL]?
}

struct AddURLRequest: Codable {
	let url0: String
	let description0: String?
	let url1: String?
	let description1: String?
	let url2: String?
	let description2: String?
	let url3: String?
	let description3: String?
}

extension AddURLRequest {
	// first returned element is parent
	func validatedInput(db: DatabaseType) throws -> TinyURL? {
		guard let url0 = URL(string: self.url0),
				let key0 = try TinyURL.makeUniqueKey(db: db) else {
			return nil
		}
		var children: [TinyURL] = []
		if let urlStr1 = self.url1, let url1 = URL(string: urlStr1), let key1 = try TinyURL.makeUniqueKey(db: db) {
			children.append(.init(key: key1, parentKey: key0, destination: url1, description: self.description1, children: nil))
		}
		if let urlStr2 = self.url2, let url2 = URL(string: urlStr2), let key2 = try TinyURL.makeUniqueKey(db: db) {
			children.append(.init(key: key2, parentKey: key0, destination: url2, description: self.description2, children: nil))
		}
		if let urlStr3 = self.url3, let url3 = URL(string: urlStr3), let key3 = try TinyURL.makeUniqueKey(db: db) {
			children.append(.init(key: key3, parentKey: key0, destination: url3, description: self.description3, children: nil))
		}
		return TinyURL(key: key0, parentKey: "", destination: url0, description: description0, children: children)
	}
}

extension TinyURL {
	static func db() throws -> DatabaseType {
		return Database(configuration: try SQLiteDatabaseConfiguration(databaseName))
	}
	static func initCRUD() throws {
		let db = try self.db()
		try db.create(TinyURL.self, primaryKey: \.key, policy: .reconcileTable)
	}
	static func makeUniqueKey(db: DatabaseType) throws -> String? {
		let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
		while true {
			let key = (0..<6).map { _ in
				let rnd = abs(Int.random) % chars.count
				return String(chars[chars.index(chars.startIndex, offsetBy: rnd)])
				}.joined()
			if try db.table(TinyURL.self).where(\TinyURL.key == key).count() == 0 {
				return key
			}
		}
	}
	var dict: [String:Any] {
		return ["key":key,
				"destination":destination?.absoluteString ?? "",
				"description": description ?? "",
				"hasChildren": !(children?.isEmpty ?? true),
				"children": children?.map { $0.dict } ?? []]
	}
}

