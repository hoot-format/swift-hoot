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
}
