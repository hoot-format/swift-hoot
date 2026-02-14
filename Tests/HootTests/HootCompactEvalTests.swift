#if canImport(FoundationModels)
import Testing
import FoundationModels
@testable import Hoot

@available(macOS 26.0, iOS 26.0, *)
private func generateTurtleFromHoot(_ compact: String, instructions: String) async throws -> String {
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(to: compact)
    return response.content
}

@Suite("HOOT Compact → Turtle Evaluation")
struct HootCompactEvalTests {

    // MARK: - Ground Truth Turtle

    static let groundTruthTurtle = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

        ex:Person a owl:Class ; rdfs:label "Person" ; rdfs:subClassOf owl:Thing .
        ex:Politician a owl:Class ; rdfs:label "Politician" ; rdfs:subClassOf ex:Person .
        ex:Scientist a owl:Class ; rdfs:label "Scientist" ; rdfs:subClassOf ex:Person .
        ex:Organization a owl:Class ; rdfs:label "Organization" ; rdfs:subClassOf owl:Thing .
        ex:Company a owl:Class ; rdfs:label "Company" ; rdfs:subClassOf ex:Organization .
        ex:GovernmentAgency a owl:Class ; rdfs:label "Government Agency" ; rdfs:subClassOf ex:Organization .
        ex:Municipality a owl:Class ; rdfs:label "Municipality" ; rdfs:subClassOf ex:GovernmentAgency .
        ex:Place a owl:Class ; rdfs:label "Place" ; rdfs:subClassOf owl:Thing .
        ex:Country a owl:Class ; rdfs:label "Country" ; rdfs:subClassOf ex:Place .
        ex:Event a owl:Class ; rdfs:label "Event" ; rdfs:subClassOf owl:Thing .

        ex:partOf a owl:ObjectProperty, owl:TransitiveProperty ;
            rdfs:label "part of" ; owl:inverseOf ex:hasPart .
        ex:locatedIn a owl:ObjectProperty, owl:TransitiveProperty ;
            rdfs:label "located in" ; rdfs:range ex:Place .
        ex:hasFounder a owl:ObjectProperty ;
            rdfs:label "has founder" ; owl:inverseOf ex:founderOf .

        ex:startDate a owl:DatatypeProperty ;
            rdfs:label "start date" ; rdfs:domain ex:Event ; rdfs:range xsd:date .

        [] a owl:AllDisjointClasses ; owl:members ( ex:Person ex:Organization ) .
        [] a owl:AllDisjointClasses ; owl:members ( ex:Person ex:Place ) .

        ex:Parent a owl:Class ; rdfs:label "Parent" ;
            owl:equivalentClass [
                a owl:Restriction ;
                owl:onProperty ex:hasChild ;
                owl:someValuesFrom owl:Thing
            ] .

        ex:Toyota a ex:Company ;
            rdfs:label "Toyota" ;
            ex:locatedIn ex:Japan ;
            ex:hasFounder ex:KiichiroToyoda ;
            ex:startDate "1937-08-28"^^xsd:date .
        """

    // MARK: - Build HootDocument (Compact)

    static func buildCompactDocument() -> HootDocument {
        HootDocument(
            prefixes: [
                HootPrefix(name: "ex", iri: "http://example.org/"),
            ],
            sections: [
                .classHierarchy(HootClassHierarchy(
                    root: "owl:Thing",
                    classes: [
                        HootClass(iri: "Person", children: [
                            HootClass(iri: "Politician"),
                            HootClass(iri: "Scientist"),
                        ]),
                        HootClass(iri: "Organization", children: [
                            HootClass(iri: "Company"),
                            HootClass(iri: "GovernmentAgency", label: "Government Agency", children: [
                                HootClass(iri: "Municipality"),
                            ]),
                        ]),
                        HootClass(iri: "Place", children: [
                            HootClass(iri: "Country"),
                        ]),
                        HootClass(iri: "Event"),
                    ]
                )),
                .tabular(HootTabularSection(
                    name: "->",
                    fields: ["iri", "inverse", "characteristics", "domain", "range"],
                    rows: [
                        ["partOf", "hasPart", "transitive"],
                        ["locatedIn", "", "transitive", "", "Place"],
                        ["hasFounder", "founderOf"],
                    ]
                )),
                .tabular(HootTabularSection(
                    name: "=>",
                    fields: ["iri", "domain", "range"],
                    rows: [
                        ["startDate", "Event", "xsd:date"],
                    ]
                )),
                .disjoint(HootDisjointSection(
                    groups: [
                        ["Person", "Organization"],
                        ["Person", "Place"],
                    ]
                )),
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Parent",
                    properties: [
                        HootProperty(predicate: "owl:equivalentClass", objects: [
                            .inlineBlankNode([
                                HootProperty(predicate: "a", objects: [.iri("owl:Restriction")]),
                                HootProperty(predicate: "owl:onProperty", objects: [.iri("ex:hasChild")]),
                                HootProperty(predicate: "owl:someValuesFrom", objects: [.iri("owl:Thing")]),
                            ]),
                        ]),
                    ]
                )),
                .subjectBlock(HootSubjectBlock(
                    subject: "ex:Toyota",
                    properties: [
                        HootProperty(predicate: "a", objects: [.iri("ex:Company")]),
                        HootProperty(predicate: "rdfs:label", objects: [.literal("Toyota")]),
                        HootProperty(predicate: "ex:locatedIn", objects: [.iri("ex:Japan")]),
                        HootProperty(predicate: "ex:hasFounder", objects: [.iri("ex:KiichiroToyoda")]),
                        HootProperty(predicate: "ex:startDate", objects: [
                            .literal("1937-08-28", datatype: "xsd:date"),
                        ]),
                    ]
                )),
            ]
        )
    }

    // MARK: - HOOT Spec (decoding rules for LLM)

    static let hootDecodingRules = "次の文章をTurtleに直してください。出力はコードブロックに書いてください。"

    // MARK: - Helpers

    static func extractCodeBlock(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inside = false
        var result: [String] = []
        for line in lines {
            if line.hasPrefix("```") {
                if inside { break }
                inside = true
                continue
            }
            if inside {
                result.append(line)
            }
        }
        return inside ? result.joined(separator: "\n") : text
    }

    // MARK: - Expected Patterns

    static let expectedPatterns: [String] = [
        // Classes
        "ex:Person a owl:Class",
        "rdfs:label \"Person\"",
        "rdfs:subClassOf owl:Thing",
        "ex:Politician a owl:Class",
        "rdfs:subClassOf ex:Person",
        "ex:Scientist a owl:Class",
        "ex:Organization a owl:Class",
        "ex:Company a owl:Class",
        "rdfs:subClassOf ex:Organization",
        "ex:GovernmentAgency a owl:Class",
        "rdfs:label \"Government Agency\"",
        "ex:Municipality a owl:Class",
        "rdfs:subClassOf ex:GovernmentAgency",
        "ex:Place a owl:Class",
        "ex:Country a owl:Class",
        "rdfs:subClassOf ex:Place",
        "ex:Event a owl:Class",
        // ObjectProperty
        "ex:partOf a owl:ObjectProperty",
        "owl:TransitiveProperty",
        "owl:inverseOf ex:hasPart",
        "ex:locatedIn a owl:ObjectProperty",
        "rdfs:range ex:Place",
        "ex:hasFounder a owl:ObjectProperty",
        "owl:inverseOf ex:founderOf",
        // DataProperty
        "ex:startDate a owl:DatatypeProperty",
        "rdfs:domain ex:Event",
        "rdfs:range xsd:date",
        // Disjoint
        "owl:AllDisjointClasses",
        "ex:Person ex:Organization",
        "ex:Person ex:Place",
        // Restriction
        "owl:equivalentClass",
        "owl:Restriction",
        "owl:onProperty ex:hasChild",
        "owl:someValuesFrom owl:Thing",
        // Individual
        "ex:Toyota a ex:Company",
        "rdfs:label \"Toyota\"",
        "ex:locatedIn ex:Japan",
        "ex:hasFounder ex:KiichiroToyoda",
        "\"1937-08-28\"^^xsd:date",
    ]

    // MARK: - Tests

    @Test("LLM reconstructs Turtle from HOOT Compact")
    func reconstructTurtle() async throws {
        guard #available(macOS 26.0, iOS 26.0, *) else { return }

        // 1. Encode to HOOT Compact
        let doc = Self.buildCompactDocument()
        let encoder = HootEncoder(mode: .compact)
        let compact = encoder.encode(doc)

        print("=== HOOT Compact Input ===")
        print(compact)

        // 2. Send to on-device LLM
        let raw = try await generateTurtleFromHoot(compact, instructions: Self.hootDecodingRules)
        let reconstructed = Self.extractCodeBlock(raw)

        print("=== Reconstructed Turtle ===")
        print(reconstructed)

        // 3. Check expected patterns
        var missing: [String] = []
        for pattern in Self.expectedPatterns {
            if !reconstructed.contains(pattern) {
                missing.append(pattern)
            }
        }

        if !missing.isEmpty {
            print("=== Missing Patterns (\(missing.count)/\(Self.expectedPatterns.count)) ===")
            for m in missing {
                print("  - \(m)")
            }
        }

        let found = Self.expectedPatterns.count - missing.count
        let total = Self.expectedPatterns.count
        let recall = Double(found) / Double(total) * 100
        print("=== Recall: \(found)/\(total) (\(String(format: "%.1f", recall))%) ===")

        #expect(missing.isEmpty, "Missing \(missing.count) patterns: \(missing)")
    }
}
#endif
