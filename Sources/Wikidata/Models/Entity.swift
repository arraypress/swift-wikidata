//
//  Entity.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A resolved entity — the knowledge-graph record.
///
/// Item references are returned as **names**, not `Q`-numbers: an answer of
/// "human, association football player" is useful where "Q5, Q937857" is not.
public struct Entity: Sendable, Codable, Equatable, Identifiable {
    /// The Q-number — `Q42`.
    public let id: String
    /// Its name in the requested language.
    public let label: String?
    /// The one-line disambiguator — "British author".
    public let description: String?
    /// Other names it goes by, in the requested language.
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
