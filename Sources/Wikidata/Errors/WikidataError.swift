//
//  WikidataError.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading the knowledge graph.
public enum WikidataError: Error, LocalizedError, Sendable, Equatable {
    case http(Int)
    case rateLimited(retryAfter: Int?)
    case malformed(String)
    case notFound(String)
    /// An id that is not a `Q`-number.
    case badIdentifier(String)

    /// A one-line reason, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case .http(let code): return "Wikidata answered HTTP \(code)"
        case .rateLimited(let after):
            return "Wikidata is rate-limiting" + (after.map { " (retry after \($0)s)" } ?? "")
        case .malformed(let what): return "unexpected response shape: \(what)"
        case .notFound(let what): return "no such \(what)"
        case .badIdentifier(let id): return "\(id) is not a Wikidata item id (expected Q…)"
        }
    }
}
