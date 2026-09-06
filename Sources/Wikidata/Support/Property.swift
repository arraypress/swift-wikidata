//
//  Property.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The property ids this library reads.
enum Property {
    static let instanceOf = "P31"
    static let occupation = "P106"
    static let citizenship = "P27"
    static let birthDate = "P569"
    static let deathDate = "P570"
    static let image = "P18"

    /// Properties whose values are item references needing a second lookup.
    static let itemValued = [instanceOf, occupation, citizenship]
}
