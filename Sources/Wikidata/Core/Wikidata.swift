//
//  Wikidata.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//
//  A knowledge graph, keyless.
//
//  Wikidata answers "what is this thing?" with structured facts: what kind of
//  entity it is, when it was born, where it is from, what it is pictured as,
//  and which Wikipedia article describes it. It needs no key and no account,
//  and it is the graph Google's own deprecated Knowledge Graph API drew from.
//
//  What this library adds over the raw API is resolution: statements point at
//  other items by `Q`-number, so a bare lookup answers "Q5, Q937857" where a
//  caller wanted "human, association football player". Those references are
//  resolved in ONE extra batched request, not one per reference.
//

import Foundation

/// A keyless client for Wikidata.
public struct Wikidata: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Wikimedia asks that tools identify themselves; anonymous bulk callers
    /// get throttled first.
    public static let defaultUserAgent = "swift-wikidata/0.1 (+https://github.com/arraypress/swift-wikidata)"
    public static let defaultHost = "www.wikidata.org"

    /// The API takes at most fifty ids in one `wbgetentities` call.
    public static let maximumBatch = 50

    public let userAgent: String
    private let host: String
    private let transport: Transport

    public init(userAgent: String = Wikidata.defaultUserAgent,
                host: String = Wikidata.defaultHost,
                transport: Transport? = nil) {
        self.userAgent = userAgent
        self.host = host
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw WikidataError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Search

    /// Candidate entities for a name, best match first.
    public func search(_ query: String, limit: Int = 10) async throws -> [SearchHit] {
        let data = try await get([
            "action": "wbsearchentities",
            "search": query,
            "language": "en",
            "uselang": "en",
            "type": "item",
            "limit": String(min(max(limit, 1), 50)),
            "format": "json",
        ])
        struct Response: Decodable { let search: [SearchHit]? }
        return try decode(Response.self, from: data).search ?? []
    }

    // MARK: - Lookup

    /// The entity behind a name — search, then resolve the best match.
    ///
    /// Two requests plus one to resolve references. Returns `nil` when nothing
    /// matches, rather than throwing: "no such person" is an answer.
    public func lookup(_ query: String) async throws -> Entity? {
        guard let hit = try await search(query, limit: 1).first else { return nil }
        return try await entity(hit.id)
    }

    /// One entity by id, with its item references resolved to names.
    public func entity(_ id: String) async throws -> Entity {
        guard let entity = try await entities([id]).first else {
            throw WikidataError.notFound("entity \(id)")
        }
        return entity
    }

    /// Several entities at once.
    ///
    /// - Note: Costs two requests regardless of how many ids are asked for —
    ///   one for the entities, one to resolve every item reference they make
    ///   between them.
    public func entities(_ ids: [String]) async throws -> [Entity] {
        let wanted = ids.map { $0.uppercased() }
        for id in wanted where !Wikidata.isItemID(id) {
            throw WikidataError.badIdentifier(id)
        }
        guard !wanted.isEmpty else { return [] }
        guard wanted.count <= Wikidata.maximumBatch else {
            throw WikidataError.badIdentifier("at most \(Wikidata.maximumBatch) ids per call")
        }

        let data = try await get([
            "action": "wbgetentities",
            "ids": wanted.joined(separator: "|"),
            "props": "labels|descriptions|aliases|claims|sitelinks/urls",
            // Both codes, because many items have only `mul` — see `Labels`.
            "languages": Labels.parameter,
            "sitefilter": "enwiki",
            "format": "json",
        ])
        let raw = try decode(EntitiesResponse.self, from: data)

        // Every item reference across every entity, resolved in one request.
        let referenced = Set(raw.entities.values.flatMap { blob in
            Property.itemValued.flatMap { Claims.itemIDs(blob.claims, $0) }
        })
        let names = try await labels(for: Array(referenced))

        // Return them in the order asked for, skipping ids the API did not know.
        return wanted.compactMap { id in
            guard let blob = raw.entities[id] else { return nil }
            return blob.entity(id: id, resolving: names)
        }
    }

    /// Labels for a batch of ids, `Q`-number → name.
    ///
    /// Chunked to the API's fifty-per-call limit; a well-connected entity can
    /// easily reference more than that.
    public func labels(for ids: [String]) async throws -> [String: String] {
        guard !ids.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for chunk in stride(from: 0, to: ids.count, by: Wikidata.maximumBatch).map({
            Array(ids[$0..<min($0 + Wikidata.maximumBatch, ids.count)])
        }) {
            let data = try await get([
                "action": "wbgetentities",
                "ids": chunk.joined(separator: "|"),
                "props": "labels",
                "languages": Labels.parameter,
                "format": "json",
            ])
            let raw = try decode(EntitiesResponse.self, from: data)
            for (id, blob) in raw.entities {
                if let label = Labels.best(from: blob.labels) { out[id] = label }
            }
        }
        return out
    }

    /// Whether `id` looks like an item id.
    public static func isItemID(_ id: String) -> Bool {
        guard id.hasPrefix("Q"), id.count > 1 else { return false }
        return id.dropFirst().allSatisfy(\.isNumber)
    }

    // MARK: - Transport

    private func get(_ query: [String: String]) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/w/api.php"
        components.queryItems = query
            .map { URLQueryItem(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }

        guard let url = components.url else {
            throw WikidataError.malformed("could not build a URL")
        }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200:
            return data
        case 429:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw WikidataError.rateLimited(retryAfter: after)
        default:
            throw WikidataError.http(response.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WikidataError.malformed(error.localizedDescription)
        }
    }
}

// MARK: - The wire shape

/// `wbgetentities`' envelope.
struct EntitiesResponse: Decodable, Sendable {
    let entities: [String: EntityBlob]

    private enum CodingKeys: String, CodingKey { case entities }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.entities = (try? container.decode([String: EntityBlob].self, forKey: .entities)) ?? [:]
    }
}

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
