import Testing
@testable import Hoot

@Suite("HootCompiler")
struct HootCompilerTests {

    @Test("Compiles class hierarchy from Turtle")
    func classHierarchy() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:Person a owl:Class ; rdfs:label "Person" ; rdfs:subClassOf owl:Thing .
        ex:Politician a owl:Class ; rdfs:label "Politician" ; rdfs:subClassOf ex:Person .
        ex:Organization a owl:Class ; rdfs:label "Organization" ; rdfs:subClassOf owl:Thing .
        """

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        // Should have a class hierarchy section
        let hierarchy = hootDoc.sections.compactMap { section -> HootClassHierarchy? in
            if case .classHierarchy(let h) = section { return h }
            return nil
        }.first

        #expect(hierarchy != nil)
        #expect(hierarchy?.root == "owl:Thing")
        #expect(hierarchy?.classes.count == 2) // Person, Organization

        let person = hierarchy?.classes.first(where: { $0.iri == "ex:Person" })
        #expect(person != nil)
        #expect(person?.label == "Person")
        #expect(person?.children.count == 1)
        #expect(person?.children.first?.iri == "ex:Politician")
    }

    @Test("Compiles object property table from Turtle")
    func objectPropertyTable() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:partOf a owl:ObjectProperty, owl:TransitiveProperty ;
            rdfs:label "part of" ; owl:inverseOf ex:hasPart .
        ex:hasFounder a owl:ObjectProperty ;
            rdfs:label "has founder" ; owl:inverseOf ex:founderOf .
        """

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let tabular = hootDoc.sections.compactMap { section -> HootTabularSection? in
            if case .tabular(let t) = section, t.name == "ObjectProperty" { return t }
            return nil
        }.first

        #expect(tabular != nil)
        #expect(tabular?.fields.contains("iri") == true)
        #expect(tabular?.fields.contains("inverse") == true)
        #expect(tabular?.fields.contains("characteristics") == true)
        #expect(tabular?.rows.count == 2)
    }

    @Test("Compiles datatype property table from Turtle")
    func dataPropertyTable() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

        ex:startDate a owl:DatatypeProperty ;
            rdfs:label "start date" ; rdfs:domain ex:Event ; rdfs:range xsd:date .
        """

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let tabular = hootDoc.sections.compactMap { section -> HootTabularSection? in
            if case .tabular(let t) = section, t.name == "DataProperty" { return t }
            return nil
        }.first

        #expect(tabular != nil)
        #expect(tabular?.rows.count == 1)
    }

    @Test("Compiles disjoint section from Turtle")
    func disjointSection() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .

        [] a owl:AllDisjointClasses ; owl:members ( ex:Person ex:Organization ) .
        [] a owl:AllDisjointClasses ; owl:members ( ex:Person ex:Place ) .
        """

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let disjoint = hootDoc.sections.compactMap { section -> HootDisjointSection? in
            if case .disjoint(let d) = section { return d }
            return nil
        }.first

        #expect(disjoint != nil)
        #expect(disjoint?.groups.count == 2)
    }

    @Test("Compiles subject blocks for remaining triples")
    func subjectBlocks() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

        ex:Toyota a ex:Company ;
            rdfs:label "Toyota" ;
            ex:startDate "1937-08-28"^^xsd:date .
        """

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let blocks = hootDoc.sections.compactMap { section -> HootSubjectBlock? in
            if case .subjectBlock(let b) = section { return b }
            return nil
        }

        #expect(blocks.count == 1)
        #expect(blocks[0].subject == "ex:Toyota")
        #expect(blocks[0].properties.count == 3)
    }

    @Test("End-to-end: Turtle → HootDocument → HOOT text")
    func endToEnd() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

        ex:Person a owl:Class ; rdfs:label "Person" ; rdfs:subClassOf owl:Thing .
        ex:Politician a owl:Class ; rdfs:label "Politician" ; rdfs:subClassOf ex:Person .

        ex:partOf a owl:ObjectProperty, owl:TransitiveProperty ;
            rdfs:label "part of" ; owl:inverseOf ex:hasPart .

        ex:startDate a owl:DatatypeProperty ;
            rdfs:label "start date" ; rdfs:domain ex:Event ; rdfs:range xsd:date .

        [] a owl:AllDisjointClasses ; owl:members ( ex:Person ex:Organization ) .

        ex:Toyota a ex:Company ;
            rdfs:label "Toyota" ;
            ex:startDate "1937-08-28"^^xsd:date .
        """

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)
        let encoder = HootEncoder(mode: .lossless)
        let result = encoder.encode(hootDoc)

        #expect(result.contains("@ex //example.org"))
        #expect(result.contains("class owl:Thing"))
        #expect(result.contains(" ex:Person \"Person\""))
        #expect(result.contains("  ex:Politician \"Politician\""))
        #expect(result.contains("->{iri,label,inverse,characteristics,domain,range}:"))
        #expect(result.contains("=>{iri,label,domain,range}:"))
        #expect(result.contains("! (ex:Person ex:Organization)"))
        #expect(result.contains("ex:Toyota:"))
    }
}
