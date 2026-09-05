//
//  Claims.swift
//  Wikidata
//
//  Created by David Sherlock on 2026.
//
//  Reading statements out of the entity blob.
//
//  A claim's value is a tagged union: an item reference is
//  `{"entity-type":"item","id":"Q5"}`, a date is
//  `{"time":"+1987-06-24T00:00:00Z","precision":11}`, an image is a bare
//  filename string. Each needs its own read, and the date needs its precision
//  respected — precision 9 means "1987", and printing "1987-01-01" for it
//  invents a birthday.
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

/// Statement decoding.
enum Claims {

    /// The raw claim block: property id → list of statements.
    typealias Block = [String: [Statement]]

    /// One statement.
    struct Statement: Decodable, Sendable {
        let mainsnak: Snak?

        struct Snak: Decodable, Sendable {
            let datavalue: DataValue?
        }

        struct DataValue: Decodable, Sendable {
            /// An item reference's id, when this is one.
            let itemID: String?
            /// A time value's raw string and precision, when this is one.
            let time: String?
            let precision: Int?
            /// A bare string value — a Commons filename, for instance.
            let text: String?

            private enum CodingKeys: String, CodingKey { case value }
            private enum ValueKeys: String, CodingKey { case id, time, precision }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // A string value is the whole `value`; everything else is an
                // object, so the string form has to be tried first.
                if let text = try? container.decode(String.self, forKey: .value) {
                    self.text = text
                    self.itemID = nil
                    self.time = nil
                    self.precision = nil
                    return
                }
                let value = try? container.nestedContainer(keyedBy: ValueKeys.self, forKey: .value)
                self.text = nil
                self.itemID = (try? value?.decodeIfPresent(String.self, forKey: .id)) ?? nil
                self.time = (try? value?.decodeIfPresent(String.self, forKey: .time)) ?? nil
                self.precision = (try? value?.decodeIfPresent(Int.self, forKey: .precision)) ?? nil
            }
        }
    }

    /// Every item id referenced by `property`.
    static func itemIDs(_ block: Block, _ property: String) -> [String] {
        (block[property] ?? []).compactMap { $0.mainsnak?.datavalue?.itemID }
    }

    /// The first bare string value of `property` — a Commons filename.
    static func string(_ block: Block, _ property: String) -> String? {
        (block[property] ?? []).compactMap { $0.mainsnak?.datavalue?.text }.first
    }

    /// The first date of `property`, trimmed to its stated precision.
    ///
    /// Wikidata times look like `+1987-06-24T00:00:00Z` with a precision:
    /// 11 is a day, 10 a month, 9 a year. Printing the full string for a
    /// year-precision date invents a birthday that is not recorded, so the
    /// value is cut to what is actually known.
    static func date(_ block: Block, _ property: String) -> String? {
        guard let statement = (block[property] ?? []).first(where: { $0.mainsnak?.datavalue?.time != nil }),
              let raw = statement.mainsnak?.datavalue?.time
        else { return nil }
        let precision = statement.mainsnak?.datavalue?.precision ?? 11
        // Drop the leading sign; a negative year is BCE and keeps its minus.
        let signed = raw.hasPrefix("+") ? String(raw.dropFirst()) : raw
        let datePart = signed.split(separator: "T").first.map(String.init) ?? signed
        switch precision {
        case ...9: return datePart.split(separator: "-").first.map(String.init)
        case 10: return datePart.split(separator: "-").prefix(2).joined(separator: "-")
        default: return datePart
        }
    }

    /// A direct URL for a Commons filename.
    ///
    /// `Special:FilePath` redirects to the real file, which saves resolving
    /// the hashed upload path by hand.
    static func commonsURL(filename: String?) -> String? {
        guard let filename, !filename.isEmpty,
              let escaped = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return "https://commons.wikimedia.org/wiki/Special:FilePath/\(escaped)"
    }
}
