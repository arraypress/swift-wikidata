//
//  Labels.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//
//  Reading a name out of Wikidata, which is not as simple as asking for `en`.
//
//  Wikidata has been migrating labels that are identical across languages to
//  the `mul` ("multilingual") code. A person whose name is spelled the same
//  everywhere now has NO English label at all:
//
//      Q615  (Lionel Messi)   labels: { "mul": "Lionel Messi" }
//      Q42   (Douglas Adams)  labels: { "mul": "Douglas Adams" }
//      Q76   (Barack Obama)   labels: { "mul": "…", "en": "…" }
//
//  So a client that asks for `languages=en` and reads `labels.en` gets an
//  EMPTY NAME for a large share of entities — silently, with the rest of the
//  record intact. Measured against the live API on 2026-09-05.
//
//  The fix is to ask for both codes and fall back through them.
//

import Foundation

/// Picking a display string out of a per-language block.
enum Labels {

    /// The language codes requested, in preference order.
    ///
    /// `mul` is not a fallback that rarely fires — for many items it is the
    /// only label there is.
    static let preferred = ["en", "mul", "en-gb", "en-ca"]

    /// The API parameter naming those codes.
    static var parameter: String { preferred.joined(separator: "|") }

    /// The best available string from a `{ code: { value } }` block.
    ///
    /// Falls through the preferred codes, then takes anything rather than
    /// returning nothing — a name in the wrong language beats no name.
    static func best(from block: [String: LanguageValue]?) -> String? {
        guard let block, !block.isEmpty else { return nil }
        for code in preferred {
            if let value = block[code]?.value, !value.isEmpty { return value }
        }
        return block.values.first(where: { !$0.value.isEmpty })?.value
    }

    /// Every alias, best-language first.
    static func all(from block: [String: [LanguageValue]]?) -> [String] {
        guard let block else { return [] }
        var seen = Set<String>()
        var out: [String] = []
        for code in preferred + block.keys.sorted() {
            for entry in block[code] ?? [] where !entry.value.isEmpty {
                if seen.insert(entry.value).inserted { out.append(entry.value) }
            }
        }
        return out
    }
}

/// One `{ "language": "en", "value": "…" }` entry.
public struct LanguageValue: Decodable, Sendable, Equatable {
    public let language: String
    public let value: String
}
