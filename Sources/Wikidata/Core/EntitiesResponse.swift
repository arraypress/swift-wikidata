//
//  EntitiesResponse.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// `wbgetentities`' envelope.
struct EntitiesResponse: Decodable, Sendable {
    let entities: [String: EntityBlob]

    private enum CodingKeys: String, CodingKey { case entities }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.entities = (try? container.decode([String: EntityBlob].self, forKey: .entities)) ?? [:]
    }
}
