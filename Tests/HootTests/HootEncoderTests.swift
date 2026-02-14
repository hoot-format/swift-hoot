import Testing
@testable import Hoot

@Suite("HootEncoder")
struct HootEncoderTests {

    let encoder = HootEncoder()

    @Test("Encodes prefix declarations")
    func prefixes() {
        let doc = HootDocument(
            prefixes: [("ex", "http://example.org/")]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("@prefix ex: <http://example.org/>"))
    }

    @Test("Encodes class hierarchy with indentation")
    func classHierarchy() {
        let doc = HootDocument(
            classes: [
                HootClass(name: "Person", children: [
                    HootClass(name: "Politician"),
                    HootClass(name: "Scientist"),
                ]),
                HootClass(name: "Organization", children: [
                    HootClass(name: "Company"),
                    HootClass(name: "GovernmentAgency", children: [
                        HootClass(name: "Municipality"),
                    ]),
                ]),
            ]
        )
        let result = encoder.encode(doc)
        let expected = """
        owl:Thing
         Person
          Politician
          Scientist
         Organization
          Company
          GovernmentAgency
           Municipality

        """
        #expect(result == expected)
    }

    @Test("Encodes tabular section")
    func tabularSection() {
        let doc = HootDocument(
            sections: [
                .tabular(HootTabularSection(
                    name: "ObjectProperty",
                    fields: ["iri", "inverse", "characteristics"],
                    rows: [
                        ["partOf", "hasPart", "transitive"],
                        ["locatedIn", "", "transitive"],
                        ["hasFounder", "founderOf", ""],
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("ObjectProperty{iri,inverse,characteristics}:"))
        #expect(result.contains(" partOf,hasPart,transitive"))
        #expect(result.contains(" locatedIn,,transitive"))
        // Trailing empty field should be trimmed
        #expect(result.contains(" hasFounder,founderOf"))
        #expect(!result.contains("hasFounder,founderOf,"))
    }

    @Test("Encodes inline section")
    func inlineSection() {
        let doc = HootDocument(
            sections: [
                .inline(HootInlineSection(
                    name: "Disjoint",
                    groups: [
                        ["Person", "Organization"],
                        ["Person", "Place"],
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("Disjoint: {Person,Organization},{Person,Place}"))
    }

    @Test("Encodes full document")
    func fullDocument() {
        let doc = HootDocument(
            prefixes: [("ex", "http://example.org/")],
            classes: [
                HootClass(name: "Person", children: [
                    HootClass(name: "Politician"),
                ]),
                HootClass(name: "Place", children: [
                    HootClass(name: "City"),
                ]),
            ],
            sections: [
                .tabular(HootTabularSection(
                    name: "ObjectProperty",
                    fields: ["iri", "inverse"],
                    rows: [
                        ["partOf", "hasPart"],
                    ]
                )),
                .inline(HootInlineSection(
                    name: "Disjoint",
                    groups: [["Person", "Place"]]
                )),
            ]
        )
        let result = encoder.encode(doc)

        let expected = """
        @prefix ex: <http://example.org/>

        owl:Thing
         Person
          Politician
         Place
          City

        ObjectProperty{iri,inverse}:
         partOf,hasPart

        Disjoint: {Person,Place}

        """
        #expect(result == expected)
    }

    @Test("Quotes values containing special characters")
    func quoting() {
        let doc = HootDocument(
            sections: [
                .tabular(HootTabularSection(
                    name: "Test",
                    fields: ["a", "b"],
                    rows: [
                        ["normal", "has,comma"],
                        ["has:colon", "plain"],
                        ["true", "false"],
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("\"has,comma\""))
        #expect(result.contains("\"has:colon\""))
        #expect(result.contains("\"true\""))
        #expect(result.contains("\"false\""))
    }

    @Test("Empty string is quoted")
    func emptyStringQuoted() {
        let encoder = HootEncoder()
        let doc = HootDocument(
            sections: [
                .tabular(HootTabularSection(
                    name: "T",
                    fields: ["a", "b", "c"],
                    rows: [
                        ["x", "", "y"],
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        // Middle empty field should be just empty (between commas), not quoted
        #expect(result.contains(" x,,y"))
    }
}
