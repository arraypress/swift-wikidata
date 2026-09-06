//
//  SearchHit.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A search result — enough to choose between candidates.
public struct SearchHit: Sendable, Codable, Equatable, Identifiable {
    /// The item id — `Q615`.
    public let id: String
    /// The entity name, in the requested language.
    public let label: String
    /// The one-line disambiguator: "Argentine association football player".
    public let description: String?
    /// The canonical concept URI.
    public let uri: String?

    private enum CodingKeys: String, CodingKey { case id, label, description, concepturi }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        self.label = ((try? container.decodeIfPresent(String.self, forKey: .label)) ?? nil) ?? ""
        self.description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? nil
        self.uri = (try? container.decodeIfPresent(String.self, forKey: .concepturi)) ?? nil
    }

    public init(id: String, label: String, description: String? = nil, uri: String? = nil) {
        self.id = id
        self.label = label
        self.description = description
        self.uri = uri
    }
}
