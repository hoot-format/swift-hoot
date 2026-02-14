import Testing
@testable import Hoot

@Suite("HootEncoder")
struct HootEncoderTests {

    let encoder = HootEncoder()

    @Test("Encodes prefix declarations")
    func prefixes() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("@ex //example.org"))
    }

    @Test("Compact mode omits standard prefixes")
    func compactOmitsStandardPrefixes() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [
                HootPrefix(name: "owl", iri: "http://www.w3.org/2002/07/owl#"),
                HootPrefix(name: "rdfs", iri: "http://www.w3.org/2000/01/rdf-schema#"),
                HootPrefix(name: "ex", iri: "http://example.org/"),
            ]
        )
        let result = compactEncoder.encode(doc)
        #expect(!result.contains("@owl"))
        #expect(!result.contains("@rdfs"))
        #expect(result.contains("@ex //example.org"))
    }

    @Test("Encodes class hierarchy with indentation")
    func classHierarchy() {
        let doc = HootDocument(
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person", children: [
                            HootClass(iri: "ex:Politician", label: "Politician"),
                            HootClass(iri: "ex:Scientist", label: "Scientist"),
                        ]),
                        HootClass(iri: "ex:Organization", label: "Organization", children: [
                            HootClass(iri: "ex:Company", label: "Company"),
                            HootClass(iri: "ex:GovernmentAgency", label: "Government Agency", children: [
                                HootClass(iri: "ex:Municipality", label: "Municipality"),
                            ]),
                        ]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("class owl:Thing"))
        #expect(result.contains(" ex:Person \"Person\""))
        #expect(result.contains("  ex:Politician \"Politician\""))
        #expect(result.contains("  ex:Scientist \"Scientist\""))
        #expect(result.contains(" ex:Organization \"Organization\""))
        #expect(result.contains("  ex:Company \"Company\""))
        #expect(result.contains("  ex:GovernmentAgency \"Government Agency\""))
        #expect(result.contains("   ex:Municipality \"Municipality\""))
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
        #expect(result.contains("->{iri,inverse,characteristics}:"))
        #expect(result.contains(" partOf,hasPart,transitive"))
        #expect(result.contains(" locatedIn,,transitive"))
        // Trailing empty field should be trimmed
        #expect(result.contains(" hasFounder,founderOf"))
        #expect(!result.contains("hasFounder,founderOf,"))
    }

    @Test("Encodes disjoint section")
    func disjointSection() {
        let doc = HootDocument(
            sections: [
                .disjoint(HootDisjointSection(
                    groups: [
                        ["ex:Person", "ex:Organization"],
                        ["ex:Person", "ex:Place"],
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("! (ex:Person ex:Organization),(ex:Person ex:Place)"))
    }

    @Test("Encodes subject block")
    func subjectBlock() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Parent",
                    properties: [
                        HootProperty(predicate: "a", objects: [.iri("owl:Class")]),
                        HootProperty(predicate: "rdfs:label", objects: [.literal("Parent")]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("ex:Parent:"))
        #expect(result.contains(" a owl:Class"))
        #expect(result.contains(" rdfs:label \"Parent\""))
    }

    @Test("Encodes subject block with multiple objects")
    func multipleObjects() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Alice",
                    properties: [
                        HootProperty(predicate: "ex:knows", objects: [.iri("ex:Bob"), .iri("ex:Carol")]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" ex:knows ex:Bob,ex:Carol"))
    }

    @Test("Encodes inline blank node")
    func inlineBlankNode() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Parent",
                    properties: [
                        HootProperty(predicate: "owl:equivalentClass", objects: [
                            .inlineBlankNode([
                                HootProperty(predicate: "a", objects: [.iri("owl:Restriction")]),
                                HootProperty(predicate: "owl:onProperty", objects: [.iri("ex:hasChild")]),
                            ])
                        ]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" owl:equivalentClass ["))
        #expect(result.contains("  a owl:Restriction"))
        #expect(result.contains("  owl:onProperty ex:hasChild"))
        #expect(result.contains(" ]"))
    }

    @Test("Encodes collection")
    func collection() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "_:disj1",
                    properties: [
                        HootProperty(predicate: "a", objects: [.iri("owl:AllDisjointClasses")]),
                        HootProperty(predicate: "owl:members", objects: [
                            .collection([.iri("ex:Person"), .iri("ex:Organization")])
                        ]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("_:disj1:"))
        #expect(result.contains(" a owl:AllDisjointClasses"))
        #expect(result.contains(" owl:members (ex:Person ex:Organization)"))
    }

    @Test("Encodes literal with datatype")
    func literalWithDatatype() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Alice",
                    properties: [
                        HootProperty(predicate: "ex:age", objects: [.literal("30", datatype: "xsd:integer")]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" ex:age \"30\"^^xsd:integer"))
    }

    @Test("Encodes literal with language tag")
    func literalWithLanguage() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Alice",
                    properties: [
                        HootProperty(predicate: "rdfs:label", objects: [.literal("Alice", language: "en")]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" rdfs:label \"Alice\"@en"))
    }

    @Test("Encodes number and boolean values")
    func numberAndBoolean() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Thing",
                    properties: [
                        HootProperty(predicate: "ex:count", objects: [.number("42")]),
                        HootProperty(predicate: "ex:active", objects: [.boolean(true)]),
                        HootProperty(predicate: "ex:deleted", objects: [.boolean(false)]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" ex:count 42"))
        #expect(result.contains(" ex:active true"))
        #expect(result.contains(" ex:deleted false"))
    }

    @Test("Encodes blank node reference")
    func blankNodeReference() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Alice",
                    properties: [
                        HootProperty(predicate: "ex:address", objects: [.blankNode("addr1")]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" ex:address _:addr1"))
    }

    @Test("Quotes values containing special characters in tabular rows")
    func quoting() {
        let doc = HootDocument(
            sections: [
                .tabular(HootTabularSection(
                    name: "Test",
                    fields: ["a", "b"],
                    rows: [
                        ["normal", "has,comma"],
                        ["has(paren", "plain"],
                        ["true", "false"],
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("\"has,comma\""))
        #expect(result.contains("\"has(paren\""))
        #expect(result.contains("\"true\""))
        #expect(result.contains("\"false\""))
    }

    @Test("Empty field is not quoted in tabular rows")
    func emptyFieldNotQuoted() {
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

    @Test("Encodes full lossless document")
    func fullLosslessDocument() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person", children: [
                            HootClass(iri: "ex:Politician", label: "Politician"),
                        ]),
                        HootClass(iri: "ex:Place", label: "Place", children: [
                            HootClass(iri: "ex:City", label: "City"),
                        ]),
                    ]
                )),
                .tabular(HootTabularSection(
                    name: "ObjectProperty",
                    fields: ["iri", "label", "inverse"],
                    rows: [
                        ["ex:partOf", "part of", "ex:hasPart"],
                    ]
                )),
                .disjoint(HootDisjointSection(
                    groups: [["ex:Person", "ex:Place"]]
                )),
            ]
        )
        let result = encoder.encode(doc)

        #expect(result.contains("@ex //example.org"))
        #expect(result.contains("class owl:Thing"))
        #expect(result.contains(" ex:Person \"Person\""))
        #expect(result.contains("  ex:Politician \"Politician\""))
        #expect(result.contains(" ex:Place \"Place\""))
        #expect(result.contains("  ex:City \"City\""))
        #expect(result.contains("->{iri,label,inverse}:"))
        #expect(result.contains(" ex:partOf,part of,ex:hasPart"))
        #expect(result.contains("! (ex:Person ex:Place)"))
    }

    @Test("Escapes special characters in strings")
    func escapeCharacters() {
        let doc = HootDocument(
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Test",
                    properties: [
                        HootProperty(predicate: "rdfs:label", objects: [
                            .literal("line1\nline2\twith \"quotes\" and \\backslash")
                        ]),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("\"line1\\nline2\\twith \\\"quotes\\\" and \\\\backslash\""))
    }
}
