# swift-hoot

Swift implementation of [HOOT](https://github.com/hoot-format/spec) (Hierarchical Ontology-Optimized Tokens).

## Installation

```swift
// swift-tools-version: 6.2
dependencies: [
    .package(url: "https://github.com/hoot-format/swift-hoot.git", branch: "main"),
],
targets: [
    .target(dependencies: [
        .product(name: "Hoot", package: "swift-hoot"),
    ]),
]
```

## Usage

```swift
import Hoot

let doc = HootDocument(
    prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
    sections: [
        .classHierarchy(HootClassHierarchy(
            root: "owl:Thing",
            classes: [
                HootClass(iri: "ex:Person", label: "Person", children: [
                    HootClass(iri: "ex:Politician", label: "Politician"),
                ]),
            ]
        )),
        .tabular(HootTabularSection(
            name: "ObjectProperty",  // Encoded as "->"
            fields: ["iri", "label", "inverse"],
            rows: [
                ["ex:partOf", "part of", "ex:hasPart"],
            ]
        )),
    ]
)

// Lossless (round-trip with Turtle)
let lossless = HootEncoder(mode: .lossless).encode(doc)

// Compact (minimum tokens)
let compact = HootEncoder(mode: .compact).encode(doc)
```

**Lossless output:**

```
@ex //example.org

class owl:Thing
 ex:Person "Person"
  ex:Politician "Politician"

->{iri,label,inverse}:
 ex:partOf,part of,ex:hasPart
```

## API

### HootDocument

```swift
HootDocument(prefixes: [HootPrefix], sections: [HootSection])
```

### HootSection

| Case | Type | Description |
|------|------|-------------|
| `.classHierarchy` | `HootClassHierarchy` | OWL class hierarchy |
| `.tabular` | `HootTabularSection` | ObjectProperty, DataProperty, etc. |
| `.disjoint` | `HootDisjointSection` | Disjoint class sets |
| `.subjectBlock` | `HootSubjectBlock` | General-purpose triples |

### HootValue

| Case | Example |
|------|---------|
| `.iri("ex:Person")` | IRI reference |
| `.literal("text", datatype: "xsd:string")` | Typed literal |
| `.literal("hello", language: "en")` | Language-tagged literal |
| `.number("42")` | Numeric literal |
| `.boolean(true)` | Boolean literal |
| `.blankNode("b0")` | Blank node reference |
| `.inlineBlankNode([...])` | Anonymous blank node |
| `.collection([...])` | RDF collection |

### HootEncoder

```swift
let encoder = HootEncoder(mode: .lossless)  // or .compact
let output = encoder.encode(document)
```

## Requirements

- Swift 6.2+
- No external dependencies

## License

MIT
