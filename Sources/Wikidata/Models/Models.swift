//
//  Models.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A search result — enough to choose between candidates.
public struct SearchHit: Sendable, Codable, Equatable, Identifiable {
    /// The item id — `Q615`.
    public let id: String
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

/// A resolved entity — the knowledge-graph record.
///
/// Item references are returned as **names**, not `Q`-numbers: an answer of
/// "human, association football player" is useful where "Q5, Q937857" is not.
public struct Entity: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let label: String?
    public let description: String?
    public let aliases: [String]
    /// What kind of thing this is — P31 "instance of", resolved.
    public let types: [String]
    /// P106 "occupation", resolved.
    public let occupations: [String]
    /// P27 "country of citizenship", resolved.
    public let nationalities: [String]
    /// P569, `yyyy-MM-dd` where the precision allows.
    public let birthDate: String?
    /// P570.
    public let deathDate: String?
    /// A direct URL to P18's image on Commons.
    public let imageURL: String?
    /// The English Wikipedia article, when there is one.
    public let wikipediaURL: String?
    /// The canonical concept URI.
    public var uri: String { "http://www.wikidata.org/entity/\(id)" }

    public init(id: String, label: String?, description: String?, aliases: [String] = [],
                types: [String] = [], occupations: [String] = [], nationalities: [String] = [],
                birthDate: String? = nil, deathDate: String? = nil,
                imageURL: String? = nil, wikipediaURL: String? = nil) {
        self.id = id
        self.label = label
        self.description = description
        self.aliases = aliases
        self.types = types
        self.occupations = occupations
        self.nationalities = nationalities
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.imageURL = imageURL
        self.wikipediaURL = wikipediaURL
    }

    /// Whether this entity is a person — P31 includes Q5, "human".
    public var isPerson: Bool {
        types.contains { $0.caseInsensitiveCompare("human") == .orderedSame }
    }
}
