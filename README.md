# swift-wikidata

A knowledge graph, keyless.

```swift
import Wikidata

let entity = try await Wikidata().lookup("Lionel Messi")
entity?.label          // "Lionel Messi"
entity?.types          // ["human"]
entity?.occupations    // ["association football player"]
entity?.nationalities  // ["Argentina"]
entity?.birthDate      // "1987-06-24"
entity?.wikipediaURL   // "https://en.wikipedia.org/wiki/Lionel_Messi"
```

## Why

Wikidata answers "what is this thing?" with structured facts, needs no key, and
is the graph Google's own — now deprecated — Knowledge Graph API drew from.

What this library adds over the raw API is **resolution**. Statements point at
other items by `Q`-number, so a bare lookup answers `Q5, Q937857` where the
caller wanted `human, association football player`. Those references are
resolved into names in **one extra batched request**, not one per reference.

```swift
try await wikidata.search("Messi", limit: 5)   // candidates, to disambiguate
try await wikidata.entity("Q615")              // one, by id
try await wikidata.entities(["Q615", "Q42"])   // many — still two requests
try await wikidata.lookup("Douglas Adams")     // search + resolve in one call
```

## The trap that makes half your results nameless

**Many entities have no English label at all.** Wikidata has been migrating
labels that are spelled the same in every language to a `mul` ("multilingual")
code:

```
Q615 (Lionel Messi)   labels: { "mul": "Lionel Messi" }          ← no "en"
Q42  (Douglas Adams)  labels: { "mul": "Douglas Adams" }         ← no "en"
Q76  (Barack Obama)   labels: { "mul": "…", "en": "…" }
```

A client that asks for `languages=en` and reads `labels.en` gets an **empty
name** — silently, with the description, dates and claims all present, so it
looks like a data problem rather than a client bug. This library requests both
codes and falls through `en → mul → en-gb → anything`.

Measured against the live API on 2026-09-05.

## Dates keep their precision

Wikidata records how precisely a date is known. Precision 9 means the year is
all anyone has, and printing `1987-01-01` for that invents a birthday:

```swift
// precision 11 → "1987-06-24"
// precision 10 → "1987-06"
// precision  9 → "1987"
```

## Politeness

Wikimedia asks that tools identify themselves, and throttles anonymous bulk
callers first. Every request carries a User-Agent; override it with your own:

```swift
let wikidata = Wikidata(userAgent: "my-tool/1.0 (+https://example.com)")
```

Batches are chunked to the API's fifty-ids-per-call limit — a well-connected
entity easily references more than that.

## Tested

19 tests. Fifteen offline, pinning the `mul` fallback, date precision, the
item-vs-string claim shapes and the one-extra-request resolution. Four are live
checks — that Messi and Douglas Adams both come back named despite having no
English label, and that no `Q`-number survives into the output. All passed
2026-09-05.

```console
$ WD_LIVE=1 swift test --filter LiveTests
```

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-wikidata.git", from: "0.1.0")
```

## Licence

MIT for this code. Wikidata's content is CC0.
