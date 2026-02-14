import Testing
@testable import Hoot

@Suite("TurtleParser")
struct TurtleParserTests {

    let parser = TurtleParser()

    @Test("Parses prefix declarations")
    func prefixes() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        """
        let doc = try parser.parse(input)
        #expect(doc.prefixes.count == 2)
        #expect(doc.prefixes[0].name == "ex")
        #expect(doc.prefixes[0].iri == "http://example.org/")
        #expect(doc.prefixes[1].name == "owl")
        #expect(doc.prefixes[1].iri == "http://www.w3.org/2002/07/owl#")
    }

    @Test("Parses simple triple")
    func simpleTriple() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Person ex:name "Alice" .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        #expect(doc.triples[0].subject == .prefixedName(prefix: "ex", local: "Person"))
        #expect(doc.triples[0].predicate == .prefixedName(prefix: "ex", local: "name"))
        #expect(doc.triples[0].object == .literal("Alice", datatype: nil, language: nil))
    }

    @Test("Parses 'a' shorthand for rdf:type")
    func aShorthand() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        ex:Person a owl:Class .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        #expect(doc.triples[0].predicate == .prefixedName(prefix: "rdf", local: "type"))
        #expect(doc.triples[0].object == .prefixedName(prefix: "owl", local: "Class"))
    }

    @Test("Parses semicolon-separated predicate-object pairs")
    func semicolon() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        ex:Person a owl:Class ; rdfs:label "Person" .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 2)
        #expect(doc.triples[0].predicate == .prefixedName(prefix: "rdf", local: "type"))
        #expect(doc.triples[1].predicate == .prefixedName(prefix: "rdfs", local: "label"))
        #expect(doc.triples[1].object == .literal("Person", datatype: nil, language: nil))
    }

    @Test("Parses comma-separated objects")
    func comma() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        ex:partOf a owl:ObjectProperty, owl:TransitiveProperty .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 2)
        #expect(doc.triples[0].object == .prefixedName(prefix: "owl", local: "ObjectProperty"))
        #expect(doc.triples[1].object == .prefixedName(prefix: "owl", local: "TransitiveProperty"))
    }

    @Test("Parses typed literal")
    func typedLiteral() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
        ex:Toyota ex:startDate "1937-08-28"^^xsd:date .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        #expect(doc.triples[0].object == .literal(
            "1937-08-28",
            datatype: .prefixedName(prefix: "xsd", local: "date"),
            language: nil
        ))
    }

    @Test("Parses language-tagged literal")
    func languageLiteral() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        ex:Person rdfs:label "Person"@en .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].object == .literal("Person", datatype: nil, language: "en"))
    }

    @Test("Parses numeric literals")
    func numericLiterals() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Thing ex:count 42 .
        ex:Thing ex:ratio 3.14 .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].object == .number("42"))
        #expect(doc.triples[1].object == .number("3.14"))
    }

    @Test("Parses boolean literals")
    func booleanLiterals() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Thing ex:active true .
        ex:Thing ex:deleted false .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].object == .boolean(true))
        #expect(doc.triples[1].object == .boolean(false))
    }

    @Test("Parses blank node property list")
    func blankNodePropertyList() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        ex:Parent owl:equivalentClass [
            a owl:Restriction ;
            owl:onProperty ex:hasChild
        ] .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 3)
        // Blank node internal triples are emitted first:
        // _:b0 a owl:Restriction
        #expect(doc.triples[0].subject == .blankNode("b0"))
        #expect(doc.triples[0].predicate == .prefixedName(prefix: "rdf", local: "type"))
        #expect(doc.triples[0].object == .prefixedName(prefix: "owl", local: "Restriction"))
        // _:b0 owl:onProperty ex:hasChild
        #expect(doc.triples[1].predicate == .prefixedName(prefix: "owl", local: "onProperty"))
        // Then the outer triple: ex:Parent owl:equivalentClass _:b0
        #expect(doc.triples[2].subject == .prefixedName(prefix: "ex", local: "Parent"))
        #expect(doc.triples[2].predicate == .prefixedName(prefix: "owl", local: "equivalentClass"))
        #expect(doc.triples[2].object == .blankNode("b0"))
    }

    @Test("Parses collection in object position")
    func collection() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        [] a owl:AllDisjointClasses ; owl:members ( ex:Person ex:Organization ) .
        """
        let doc = try parser.parse(input)
        // Should have: _:b0 a owl:AllDisjointClasses, _:b0 owl:members (collection)
        let membersTriple = doc.triples.first { triple in
            if case .prefixedName(_, let local) = triple.predicate {
                return local == "members"
            }
            return false
        }
        #expect(membersTriple != nil)
        if case .collection(let items) = membersTriple?.object {
            #expect(items.count == 2)
        } else {
            #expect(Bool(false), "Expected collection object")
        }
    }

    @Test("Parses blank node label")
    func blankNodeLabel() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        _:disj1 a owl:AllDisjointClasses .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].subject == .blankNode("disj1"))
    }

    @Test("Parses full IRI")
    func fullIRI() throws {
        let input = """
        <http://example.org/Person> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Class> .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        #expect(doc.triples[0].subject == .iri("http://example.org/Person"))
    }

    @Test("Handles comments")
    func comments() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        # This is a comment
        ex:Person a ex:Class .  # Inline comment
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
    }

    @Test("Parses trailing semicolon")
    func trailingSemicolon() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        ex:Person a owl:Class ;
            rdfs:label "Person" ;
        .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Parses empty input")
    func emptyInput() throws {
        let doc = try parser.parse("")
        #expect(doc.prefixes.isEmpty)
        #expect(doc.triples.isEmpty)
        #expect(doc.base == nil)
    }

    @Test("Parses only prefixes, no triples")
    func onlyPrefixes() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        """
        let doc = try parser.parse(input)
        #expect(doc.prefixes.count == 2)
        #expect(doc.triples.isEmpty)
    }

    @Test("Parses @base directive")
    func baseDirective() throws {
        let input = """
        @base <http://example.org/> .
        """
        let doc = try parser.parse(input)
        #expect(doc.base == "http://example.org/")
    }

    @Test("Parses SPARQL-style PREFIX without dot")
    func sparqlPrefix() throws {
        let input = """
        PREFIX ex: <http://example.org/>
        ex:Person a ex:Class .
        """
        let doc = try parser.parse(input)
        #expect(doc.prefixes.count == 1)
        #expect(doc.prefixes[0].name == "ex")
        #expect(doc.triples.count == 1)
    }

    @Test("Parses SPARQL-style BASE without dot")
    func sparqlBase() throws {
        let input = """
        BASE <http://example.org/>
        """
        let doc = try parser.parse(input)
        #expect(doc.base == "http://example.org/")
    }

    @Test("Parses empty blank node []")
    func emptyBlankNode() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        [] ex:knows ex:Alice .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        #expect(doc.triples[0].subject == .blankNode("b0"))
    }

    @Test("Parses empty collection ()")
    func emptyCollection() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Thing ex:list () .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        if case .collection(let items) = doc.triples[0].object {
            #expect(items.isEmpty)
        } else {
            #expect(Bool(false), "Expected empty collection")
        }
    }

    @Test("Parses nested blank node property lists")
    func nestedBlankNodes() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:has [
            ex:inner [
                ex:value "deep"
            ]
        ] .
        """
        let doc = try parser.parse(input)
        // Inner blank node triples emitted first
        // _:b1 ex:value "deep"
        #expect(doc.triples[0].subject == .blankNode("b1"))
        #expect(doc.triples[0].object == .literal("deep", datatype: nil, language: nil))
        // _:b0 ex:inner _:b1
        #expect(doc.triples[1].subject == .blankNode("b0"))
        #expect(doc.triples[1].object == .blankNode("b1"))
        // ex:A ex:has _:b0
        #expect(doc.triples[2].subject == .prefixedName(prefix: "ex", local: "A"))
        #expect(doc.triples[2].object == .blankNode("b0"))
    }

    @Test("Parses collection with mixed types")
    func collectionMixedTypes() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Thing ex:list ( "hello" 42 true ex:A ) .
        """
        let doc = try parser.parse(input)
        if case .collection(let items) = doc.triples[0].object {
            #expect(items.count == 4)
            #expect(items[0] == .literal("hello", datatype: nil, language: nil))
            #expect(items[1] == .number("42"))
            #expect(items[2] == .boolean(true))
            #expect(items[3] == .prefixedName(prefix: "ex", local: "A"))
        } else {
            #expect(Bool(false), "Expected collection")
        }
    }

    @Test("Parses multiple triples for same subject")
    func multipleTriplesSameSubject() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:p1 "v1" .
        ex:A ex:p2 "v2" .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 2)
        #expect(doc.triples[0].subject == doc.triples[1].subject)
    }

    @Test("Parses double literal with exponent")
    func doubleLiteral() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Thing ex:val 1.5e10 .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].object == .number("1.5e10"))
    }

    @Test("Parses typed literal with full IRI datatype")
    func typedLiteralFullIRI() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Thing ex:val "42"^^<http://www.w3.org/2001/XMLSchema#integer> .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].object == .literal(
            "42",
            datatype: .iri("http://www.w3.org/2001/XMLSchema#integer"),
            language: nil
        ))
    }

    @Test("Parses blank node as object")
    func blankNodeObject() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:knows _:someone .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples[0].object == .blankNode("someone"))
    }

    @Test("Blank node property list as subject with dot only")
    func blankNodePropertyListSubjectDotOnly() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        [ a ex:Thing ] .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.count == 1)
        #expect(doc.triples[0].subject == .blankNode("b0"))
    }

    // MARK: - Error Paths

    @Test("Throws on missing dot after triple")
    func missingDot() {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:p "v"
        """
        #expect(throws: TurtleParserError.self) {
            try parser.parse(input)
        }
    }

    @Test("Throws on missing object")
    func missingObject() {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:p .
        """
        #expect(throws: (any Error).self) {
            try parser.parse(input)
        }
    }

    @Test("Subject with only dot produces no triples")
    func subjectOnlyDot() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A .
        """
        let doc = try parser.parse(input)
        #expect(doc.triples.isEmpty)
    }

    @Test("Throws on invalid prefix declaration")
    func invalidPrefixDeclaration() {
        #expect(throws: (any Error).self) {
            try parser.parse("@prefix \"bad\" .")
        }
    }

    @Test("Throws on missing IRI in prefix declaration")
    func missingIRIInPrefix() {
        #expect(throws: (any Error).self) {
            try parser.parse("@prefix ex: .")
        }
    }

    @Test("Throws on unterminated collection")
    func unterminatedCollection() {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:p ( ex:B ex:C
        """
        #expect(throws: (any Error).self) {
            try parser.parse(input)
        }
    }

    @Test("Throws on missing IRI after @base")
    func missingIRIAfterBase() {
        #expect(throws: TurtleParserError.self) {
            try parser.parse("@base .")
        }
    }
}
