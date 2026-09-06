//
//  LanguageValue.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One `{ "language": "en", "value": "…" }` entry.
public struct LanguageValue: Decodable, Sendable, Equatable {
    /// The language code the value is in — `en`.
    public let language: String
    /// The text itself.
    public let value: String
}
