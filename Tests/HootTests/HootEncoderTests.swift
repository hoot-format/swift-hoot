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

    @Test("Compact mode omits standard prefixes and converts single custom to default")
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
        // Single custom prefix "ex" is converted to default prefix
        #expect(result.contains("@ //example.org"))
        #expect(!result.contains("@ex"))
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

    // MARK: - Default Prefix Conversion

    @Test("Compact mode converts single custom prefix in class hierarchy")
    func compactDefaultPrefixClassHierarchy() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person", children: [
                            HootClass(iri: "ex:Scientist", label: "Scientist"),
                        ]),
                        HootClass(iri: "ex:GovernmentAgency", label: "Government Agency"),
                    ]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        #expect(result.contains("@ //example.org"))
        // Bare names (no colon prefix)
        #expect(result.contains(" Person"))
        #expect(result.contains("  Scientist"))
        // Label omitted when it matches local name
        #expect(!result.contains("\"Person\""))
        #expect(!result.contains("\"Scientist\""))
        // Label kept when it differs from local name
        #expect(result.contains(" GovernmentAgency \"Government Agency\""))
        // owl:Thing should NOT be replaced
        #expect(result.contains("class owl:Thing"))
    }

    @Test("Compact mode converts single custom prefix in tabular section")
    func compactDefaultPrefixTabular() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .tabular(HootTabularSection(
                    name: "ObjectProperty",
                    fields: ["iri", "label", "inverse"],
                    rows: [
                        ["ex:partOf", "part of", "ex:hasPart"],
                        ["ex:locatedIn", "located in", ""],
                    ]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        #expect(result.contains(" partOf,part of,hasPart"))
        #expect(result.contains(" locatedIn,located in"))
    }

    @Test("Compact mode converts single custom prefix in disjoint section")
    func compactDefaultPrefixDisjoint() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .disjoint(HootDisjointSection(
                    groups: [["ex:Person", "ex:Organization"]]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        #expect(result.contains("! (Person Organization)"))
    }

    @Test("Compact mode converts single custom prefix in subject blocks")
    func compactDefaultPrefixSubjectBlock() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Toyota",
                    properties: [
                        HootProperty(predicate: "a", objects: [.iri("ex:Company")]),
                        HootProperty(predicate: "rdfs:label", objects: [.literal("Toyota")]),
                        HootProperty(predicate: "ex:locatedIn", objects: [.iri("ex:Japan")]),
                    ]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        #expect(result.contains("Toyota:"))
        #expect(result.contains(" a Company"))
        // rdfs:label should NOT be replaced
        #expect(result.contains(" rdfs:label \"Toyota\""))
        #expect(result.contains(" locatedIn Japan"))
    }

    @Test("Compact mode does NOT convert when multiple custom prefixes exist")
    func compactMultiplePrefixesNoConversion() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [
                HootPrefix(name: "ex", iri: "http://example.org/"),
                HootPrefix(name: "foaf", iri: "http://xmlns.com/foaf/0.1/"),
            ],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person"),
                        HootClass(iri: "ex:Agent", label: "エージェント"),
                    ]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        // Both prefixes kept as named
        #expect(result.contains("@ex //example.org"))
        #expect(result.contains("@foaf //xmlns.com/foaf/0.1"))
        // Prefix kept, but redundant label still omitted in compact mode
        #expect(result.contains(" ex:Person"))
        #expect(!result.contains("\"Person\""))
        // Non-matching label is kept
        #expect(result.contains(" ex:Agent \"エージェント\""))
    }

    @Test("Lossless mode does NOT convert prefix to default")
    func losslessNoConversion() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person"),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains("@ex //example.org"))
        #expect(result.contains(" ex:Person \"Person\""))
    }

    @Test("usingDefaultPrefix replaces IRIs throughout document")
    func usingDefaultPrefixMethod() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [HootClass(iri: "ex:A", children: [HootClass(iri: "ex:B")])]
                )),
                .tabular(HootTabularSection(
                    name: "ObjectProperty",
                    fields: ["iri", "inverse"],
                    rows: [["ex:p", "ex:q"]]
                )),
                .disjoint(HootDisjointSection(groups: [["ex:A", "ex:B"]])),
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:S",
                    properties: [
                        HootProperty(predicate: "ex:rel", objects: [.iri("ex:O")]),
                    ]
                )),
            ]
        )
        let converted = doc.usingDefaultPrefix("ex")

        // Prefix name changed
        #expect(converted.prefixes[0].name == "")
        #expect(converted.prefixes[0].iri == "http://example.org/")

        // Class hierarchy — bare names (no colon prefix)
        if case .classHierarchy(let h) = converted.sections[0] {
            #expect(h.root == "owl:Thing")
            #expect(h.classes[0].iri == "A")
            #expect(h.classes[0].children[0].iri == "B")
        }

        // Tabular
        if case .tabular(let t) = converted.sections[1] {
            #expect(t.rows[0] == ["p", "q"])
        }

        // Disjoint
        if case .disjoint(let d) = converted.sections[2] {
            #expect(d.groups[0] == ["A", "B"])
        }

        // Subject block
        if case .subjectBlock(let b) = converted.sections[3] {
            #expect(b.subject == "S")
            #expect(b.properties[0].predicate == "rel")
            if case .iri(let iri) = b.properties[0].objects[0] {
                #expect(iri == "O")
            }
        }
    }

    @Test("usingDefaultPrefix with nonexistent prefix returns unchanged")
    func usingDefaultPrefixNonexistent() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    classes: [HootClass(iri: "ex:A")]
                ))
            ]
        )
        let converted = doc.usingDefaultPrefix("foaf")
        #expect(converted == doc)
    }

    // MARK: - Bare Names (no colon prefix)

    @Test("usingDefaultPrefix produces bare names without colon")
    func usingDefaultPrefixBareNames() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [HootClass(iri: "ex:Person")]
                )),
                .tabular(HootTabularSection(
                    name: "ObjectProperty",
                    fields: ["iri"],
                    rows: [["ex:partOf"]]
                )),
                .disjoint(HootDisjointSection(groups: [["ex:A", "ex:B"]])),
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Toyota",
                    properties: [
                        HootProperty(predicate: "ex:locatedIn", objects: [.iri("ex:Japan")]),
                    ]
                )),
            ]
        )
        let converted = doc.usingDefaultPrefix("ex")

        // Class hierarchy
        if case .classHierarchy(let h) = converted.sections[0] {
            #expect(h.classes[0].iri == "Person")
        }
        // Tabular
        if case .tabular(let t) = converted.sections[1] {
            #expect(t.rows[0] == ["partOf"])
        }
        // Disjoint
        if case .disjoint(let d) = converted.sections[2] {
            #expect(d.groups[0] == ["A", "B"])
        }
        // Subject block
        if case .subjectBlock(let b) = converted.sections[3] {
            #expect(b.subject == "Toyota")
            #expect(b.properties[0].predicate == "locatedIn")
        }
    }

    @Test("usingDefaultPrefix does not affect other prefixes")
    func usingDefaultPrefixOtherPrefixUntouched() {
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Alice",
                    properties: [
                        HootProperty(predicate: "rdfs:label", objects: [.literal("Alice")]),
                        HootProperty(predicate: "a", objects: [.iri("owl:Thing")]),
                    ]
                ))
            ]
        )
        let converted = doc.usingDefaultPrefix("ex")

        if case .subjectBlock(let b) = converted.sections[0] {
            #expect(b.subject == "Alice")
            // rdfs: and owl: are untouched
            #expect(b.properties[0].predicate == "rdfs:label")
            if case .iri(let iri) = b.properties[1].objects[0] {
                #expect(iri == "owl:Thing")
            }
        }
    }

    // MARK: - Compact Label Omission

    @Test("Compact mode omits label matching IRI local name")
    func compactOmitsRedundantLabel() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person"),
                    ]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        // Label "Person" matches local name "Person" → omitted
        #expect(result.contains(" Person\n"))
        #expect(!result.contains("\"Person\""))
    }

    @Test("Compact mode keeps label differing from IRI local name")
    func compactKeepsDifferentLabel() {
        let compactEncoder = HootEncoder(mode: .compact)
        let doc = HootDocument(
            prefixes: [HootPrefix(name: "ex", iri: "http://example.org/")],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:GovernmentAgency", label: "Government Agency"),
                        HootClass(iri: "ex:Project", label: "プロジェクト"),
                    ]
                ))
            ]
        )
        let result = compactEncoder.encode(doc)
        #expect(result.contains(" GovernmentAgency \"Government Agency\""))
        #expect(result.contains(" Project \"プロジェクト\""))
    }

    @Test("Lossless mode always shows label even when it matches")
    func losslessKeepsMatchingLabel() {
        let doc = HootDocument(
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "ex:Person", label: "Person"),
                    ]
                ))
            ]
        )
        let result = encoder.encode(doc)
        #expect(result.contains(" ex:Person \"Person\""))
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
