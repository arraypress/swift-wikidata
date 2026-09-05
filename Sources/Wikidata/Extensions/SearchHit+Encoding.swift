//
//  SearchHit+Encoding.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//
//  Written by hand because the custom `init(from:)` suppresses synthesis, and
//  because the API's `concepturi` is spelled without a separator — the way
//  out uses `uri`.
//

import Foundation

extension SearchHit {
    private enum OutputKeys: String, CodingKey { case id, label, description, uri }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(uri, forKey: .uri)
    }
}
