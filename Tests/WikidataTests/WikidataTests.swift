//
//  WikidataTests.swift
//  WikidataTests
//
//  Created by David Sherlock on 2026.
//
//  Offline, on bodies recorded from the live API on 2026-09-05.
//

import Foundation
import XCTest
@testable import Wikidata

final class WikidataTests: XCTestCase {

    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        var bodies: [String]
        let status: Int
        init(_ bodies: [String], status: Int = 200) { self.bodies = bodies; self.status = status }
        var transport: Wikidata.Transport {
            { [self] request in
                requests.append(request)
                let body = bodies.isEmpty ? "{}" : bodies.removeFirst()
                let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: [:])!
                return (Data(body.utf8), response)
            }
        }
    }

    // MARK: - The `mul` label

    /// Messi's label is stored ONLY under `mul`. Reading `labels.en` gives an
    /// empty name with the rest of the record intact — a silent failure.
    func testALabelStoredOnlyUnderMulIsStillFound() {
        let block = ["mul": LanguageValue(language: "mul", value: "Lionel Messi")]
        XCTAssertEqual(Labels.best(from: block), "Lionel Messi")
    }

    func testEnglishWinsWhenBothExist() {
        let block = [
            "mul": LanguageValue(language: "mul", value: "Barack Obama (mul)"),
            "en": LanguageValue(language: "en", value: "Barack Obama"),
        ]
        XCTAssertEqual(Labels.best(from: block), "Barack Obama")
    }

    func testAnyLanguageBeatsNoNameAtAll() {
        let block = ["de": LanguageValue(language: "de", value: "Kölner Dom")]
        XCTAssertEqual(Labels.best(from: block), "Kölner Dom")
        XCTAssertNil(Labels.best(from: [:]))
        XCTAssertNil(Labels.best(from: nil))
    }

    func testBothLanguageCodesAreRequested() {
        XCTAssertTrue(Labels.parameter.contains("en"))
        XCTAssertTrue(Labels.parameter.contains("mul"),
                      "omitting mul is what makes half the entities come back nameless")
    }

    // MARK: - Dates and precision

    /// Precision 9 means the year is all that is recorded. Printing
    /// `1987-01-01` for it invents a birthday.
    func testADateIsTrimmedToItsStatedPrecision() {
        func block(_ time: String, _ precision: Int) -> Claims.Block {
            let json = """
            { "P569": [ { "mainsnak": { "datavalue": { "value":
              { "time": "\(time)", "precision": \(precision) } } } } ] }
            """
            return try! JSONDecoder().decode(Claims.Block.self, from: Data(json.utf8))
        }
        XCTAssertEqual(Claims.date(block("+1987-06-24T00:00:00Z", 11), "P569"), "1987-06-24")
        XCTAssertEqual(Claims.date(block("+1987-06-24T00:00:00Z", 10), "P569"), "1987-06")
        XCTAssertEqual(Claims.date(block("+1987-06-24T00:00:00Z", 9), "P569"), "1987",
                       "year precision must not invent a month and a day")
        XCTAssertEqual(Claims.date(block("+1987-06-24T00:00:00Z", 7), "P569"), "1987")
    }

    // MARK: - Claim values

    func testItemReferencesAndBareStringsAreReadDifferently() throws {
        let claims = try JSONDecoder().decode(Claims.Block.self, from: Data("""
        { "P31":  [ { "mainsnak": { "datavalue": { "value": { "entity-type": "item", "id": "Q5" } } } } ],
          "P106": [ { "mainsnak": { "datavalue": { "value": { "entity-type": "item", "id": "Q937857" } } } },
                    { "mainsnak": { "datavalue": { "value": { "entity-type": "item", "id": "Q628099" } } } } ],
          "P18":  [ { "mainsnak": { "datavalue": { "value": "Messi 2026.jpg" } } } ] }
        """.utf8))

        XCTAssertEqual(Claims.itemIDs(claims, "P31"), ["Q5"])
        XCTAssertEqual(Claims.itemIDs(claims, "P106"), ["Q937857", "Q628099"])
        XCTAssertEqual(Claims.string(claims, "P18"), "Messi 2026.jpg",
                       "an image is a bare string where a type is an object")
        XCTAssertTrue(Claims.itemIDs(claims, "P27").isEmpty)
    }

    func testACommonsFilenameBecomesAFetchableURL() {
        let url = Claims.commonsURL(filename: "Messi 2026.jpg")
        XCTAssertEqual(url, "https://commons.wikimedia.org/wiki/Special:FilePath/Messi%202026.jpg")
        XCTAssertNil(Claims.commonsURL(filename: nil))
        XCTAssertNil(Claims.commonsURL(filename: ""))
    }

    // MARK: - Resolution

    func testReferencesAreResolvedToNamesInOneExtraRequest() async throws {
        let entity = """
        { "entities": { "Q615": {
            "labels": { "mul": { "language": "mul", "value": "Lionel Messi" } },
            "descriptions": { "en": { "language": "en", "value": "Argentine footballer" } },
            "claims": {
              "P31":  [ { "mainsnak": { "datavalue": { "value": { "entity-type": "item", "id": "Q5" } } } } ],
              "P27":  [ { "mainsnak": { "datavalue": { "value": { "entity-type": "item", "id": "Q414" } } } } ],
              "P569": [ { "mainsnak": { "datavalue": { "value": { "time": "+1987-06-24T00:00:00Z", "precision": 11 } } } } ] },
            "sitelinks": { "enwiki": { "url": "https://en.wikipedia.org/wiki/Lionel_Messi" } } } } }
        """
        let labels = """
        { "entities": {
            "Q5":   { "labels": { "en": { "language": "en", "value": "human" } } },
            "Q414": { "labels": { "mul": { "language": "mul", "value": "Argentina" } } } } }
        """
        let recorder = Recorder([entity, labels])
        let result = try await Wikidata(transport: recorder.transport).entity("Q615")

        XCTAssertEqual(result.label, "Lionel Messi")
        XCTAssertEqual(result.types, ["human"], "Q5 must come back as a word")
        XCTAssertEqual(result.nationalities, ["Argentina"], "and so must a mul-only reference")
        XCTAssertEqual(result.birthDate, "1987-06-24")
        XCTAssertTrue(result.isPerson)
        XCTAssertEqual(result.uri, "http://www.wikidata.org/entity/Q615")
        XCTAssertEqual(recorder.requests.count, 2, "one for the entity, one for every reference it makes")
    }

    func testAnEntityMakingNoReferencesCostsOneRequest() async throws {
        let recorder = Recorder(["""
        { "entities": { "Q1": { "labels": { "en": { "language": "en", "value": "universe" } },
                                "claims": {} } } }
        """])
        let result = try await Wikidata(transport: recorder.transport).entity("Q1")
        XCTAssertEqual(result.label, "universe")
        XCTAssertEqual(recorder.requests.count, 1, "no references means no second request")
    }

    // MARK: - Identifiers and requests

    func testANonItemIdentifierIsRefusedBeforeARequest() async {
        let recorder = Recorder([])
        for bad in ["P31", "615", "", "Qabc", "L123"] {
            do {
                _ = try await Wikidata(transport: recorder.transport).entity(bad)
                XCTFail("\(bad) is not an item id")
            } catch let error as WikidataError {
                guard case .badIdentifier = error else { return XCTFail("expected .badIdentifier for \(bad)") }
            } catch { XCTFail("unexpected \(error)") }
        }
        XCTAssertTrue(recorder.requests.isEmpty)
        XCTAssertTrue(Wikidata.isItemID("Q615"))
        XCTAssertFalse(Wikidata.isItemID("P31"))
    }

    func testTheRequestNamesBothLanguageCodesAndIdentifiesItself() async throws {
        let recorder = Recorder([#"{ "entities": { "Q1": { "claims": {} } } }"#])
        _ = try await Wikidata(transport: recorder.transport).entity("Q1")

        let request = try XCTUnwrap(recorder.requests.first)
        let url = try XCTUnwrap(request.url?.absoluteString.removingPercentEncoding)
        XCTAssertTrue(url.contains("languages=en|mul"), url)
        XCTAssertTrue(url.contains("sitefilter=enwiki"))
        let agent = try XCTUnwrap(request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertTrue(agent.contains("swift-wikidata"), "Wikimedia throttles anonymous callers first")
    }

    func testABatchLargerThanTheAPILimitIsRefused() async {
        let recorder = Recorder([])
        let tooMany = (1...51).map { "Q\($0)" }
        do {
            _ = try await Wikidata(transport: recorder.transport).entities(tooMany)
            XCTFail("the API takes fifty at a time")
        } catch {
            XCTAssertTrue(recorder.requests.isEmpty)
        }
    }

    func testAnUnknownEntityIsNotFound() async {
        let recorder = Recorder([#"{ "entities": {} }"#])
        do {
            _ = try await Wikidata(transport: recorder.transport).entity("Q99999999")
            XCTFail("the API returned nothing for it")
        } catch let error as WikidataError {
            guard case .notFound = error else { return XCTFail("expected .notFound, got \(error)") }
        } catch { XCTFail("unexpected \(error)") }
    }

    func testALookupThatMatchesNothingReturnsNilRatherThanThrowing() async throws {
        let recorder = Recorder([#"{ "search": [] }"#])
        let result = try await Wikidata(transport: recorder.transport).lookup("asdkjhasd")
        XCTAssertNil(result, "\"no such person\" is an answer, not a failure")
    }

    func testARateLimitIsItsOwnError() async {
        let recorder = Recorder([""], status: 429)
        do {
            _ = try await Wikidata(transport: recorder.transport).search("x")
            XCTFail("429 must not pass")
        } catch let error as WikidataError {
            XCTAssertEqual(error, .rateLimited(retryAfter: nil))
        } catch { XCTFail("unexpected \(error)") }
    }
}
