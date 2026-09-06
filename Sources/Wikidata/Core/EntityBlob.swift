//
//  EntityBlob.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One entity as the API sends it.
struct EntityBlob: Decodable, Sendable {
    let labels: [String: LanguageValue]?
    let descriptions: [String: LanguageValue]?
    let aliases: [String: [LanguageValue]]?
    let claims: Claims.Block
    let sitelinks: [String: Sitelink]?

    struct Sitelink: Decodable, Sendable { let url: String? }

    private enum CodingKeys: String, CodingKey { case labels, descriptions, aliases, claims, sitelinks }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.labels = (try? container.decodeIfPresent([String: LanguageValue].self, forKey: .labels)) ?? nil
        self.descriptions = (try? container.decodeIfPresent([String: LanguageValue].self, forKey: .descriptions)) ?? nil
        self.aliases = (try? container.decodeIfPresent([String: [LanguageValue]].self, forKey: .aliases)) ?? nil
        self.claims = ((try? container.decodeIfPresent(Claims.Block.self, forKey: .claims)) ?? nil) ?? [:]
        self.sitelinks = (try? container.decodeIfPresent([String: Sitelink].self, forKey: .sitelinks)) ?? nil
    }

    /// Turns the blob into the public type, naming its item references.
    func entity(id: String, resolving names: [String: String]) -> Entity {
        func resolved(_ property: String) -> [String] {
            Claims.itemIDs(claims, property).compactMap { names[$0] }
        }
        return Entity(
            id: id,
            label: Labels.best(from: labels),
            description: Labels.best(from: descriptions),
            aliases: Labels.all(from: aliases),
            types: resolved(Property.instanceOf),
            occupations: resolved(Property.occupation),
            nationalities: resolved(Property.citizenship),
            birthDate: Claims.date(claims, Property.birthDate),
            deathDate: Claims.date(claims, Property.deathDate),
            imageURL: Claims.commonsURL(filename: Claims.string(claims, Property.image)),
            wikipediaURL: sitelinks?["enwiki"]?.url
        )
    }
}
