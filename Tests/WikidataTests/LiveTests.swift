//
//  LiveTests.swift
//  WikidataTests
//
//      WD_LIVE=1 swift test --filter LiveTests
//

import Foundation
import XCTest
@testable import Wikidata

final class LiveTests: XCTestCase {

    private var isEnabled: Bool { ProcessInfo.processInfo.environment["WD_LIVE"] == "1" }

    /// The `mul` case is the whole reason this library exists in this shape:
    /// Messi has NO English label, only a multilingual one. A client that asks
    /// for `en` alone gets a nameless record back.
    func testAnEntityWithNoEnglishLabelStillComesBackNamed() async throws {
        try XCTSkipUnless(isEnabled, "set WD_LIVE=1 to run")

        let messi = try await Wikidata().entity("Q615")
        XCTAssertEqual(messi.label, "Lionel Messi", "his label is stored under `mul`, not `en`")
        XCTAssertNotNil(messi.description)
        XCTAssertTrue(messi.isPerson, "types: \(messi.types)")
        XCTAssertTrue(messi.types.contains("human"), "\(messi.types)")
        XCTAssertEqual(messi.birthDate, "1987-06-24")
        XCTAssertTrue(messi.nationalities.contains("Argentina"), "\(messi.nationalities)")
        XCTAssertFalse(messi.occupations.isEmpty)
        XCTAssertNotNil(messi.imageURL)
        XCTAssertEqual(messi.wikipediaURL, "https://en.wikipedia.org/wiki/Lionel_Messi")
    }

    func testReferencesComeBackAsNamesNotQNumbers() async throws {
        try XCTSkipUnless(isEnabled, "set WD_LIVE=1 to run")

        let adams = try await Wikidata().entity("Q42")
        XCTAssertEqual(adams.label, "Douglas Adams", "also a `mul`-only label")
        for value in adams.types + adams.occupations + adams.nationalities {
            XCTAssertFalse(Wikidata.isItemID(value), "\(value) was left as a Q-number")
        }
        XCTAssertTrue(adams.occupations.contains { $0.contains("writer") || $0.contains("novelist") },
                      "\(adams.occupations)")
        XCTAssertNotNil(adams.deathDate)
    }

    func testSearchThenLookupAnswersAPlainName() async throws {
        try XCTSkipUnless(isEnabled, "set WD_LIVE=1 to run")

        let entity = try await Wikidata().lookup("Barack Obama")
        let found = try XCTUnwrap(entity)
        XCTAssertEqual(found.label, "Barack Obama")
        XCTAssertTrue(found.isPerson)
        XCTAssertTrue(found.nationalities.contains { $0.hasPrefix("United States") }, "\(found.nationalities)")
    }

    func testABatchCostsTwoRequestsNotTwoPerEntity() async throws {
        try XCTSkipUnless(isEnabled, "set WD_LIVE=1 to run")
        let entities = try await Wikidata().entities(["Q615", "Q42", "Q76"])
        XCTAssertEqual(entities.count, 3)
        XCTAssertEqual(entities.map(\.id), ["Q615", "Q42", "Q76"], "order asked for is order returned")
        XCTAssertTrue(entities.allSatisfy { $0.label?.isEmpty == false })
    }
}
