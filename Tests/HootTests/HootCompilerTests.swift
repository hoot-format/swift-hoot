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

    // MARK: - Edge Cases

    @Test("Compiles empty document")
    func emptyDocument() throws {
        let turtleDoc = TurtleDocument()
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)
        #expect(hootDoc.sections.isEmpty)
        #expect(hootDoc.prefixes.isEmpty)
    }

    @Test("Compiles document with only prefixes")
    func onlyPrefixes() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)
        #expect(hootDoc.prefixes.count == 2)
        #expect(hootDoc.sections.isEmpty)
    }

    @Test("Class without label has nil label")
    func classWithoutLabel() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:Thing a owl:Class ; rdfs:subClassOf owl:Thing .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let hierarchy = hootDoc.sections.compactMap { section -> HootClassHierarchy? in
            if case .classHierarchy(let h) = section { return h }
            return nil
        }.first

        #expect(hierarchy != nil)
        #expect(hierarchy?.classes.first?.label == nil)
    }

    @Test("Class without subClassOf defaults to owl:Thing")
    func classDefaultParent() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .

        ex:Foo a owl:Class .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let hierarchy = hootDoc.sections.compactMap { section -> HootClassHierarchy? in
            if case .classHierarchy(let h) = section { return h }
            return nil
        }.first

        #expect(hierarchy != nil)
        #expect(hierarchy?.classes.count == 1)
        #expect(hierarchy?.classes.first?.iri == "ex:Foo")
    }

    @Test("Class with extra properties emits subject block")
    func classExtraProperties() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:Parent a owl:Class ; rdfs:label "Parent" ;
            owl:equivalentClass [
                a owl:Restriction ;
                owl:onProperty ex:hasChild ;
                owl:someValuesFrom owl:Thing
            ] .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        // Should have hierarchy
        let hierarchy = hootDoc.sections.compactMap { section -> HootClassHierarchy? in
            if case .classHierarchy(let h) = section { return h }
            return nil
        }.first
        #expect(hierarchy != nil)
        #expect(hierarchy?.classes.first?.iri == "ex:Parent")

        // And also a subject block for equivalentClass
        let blocks = hootDoc.sections.compactMap { section -> HootSubjectBlock? in
            if case .subjectBlock(let b) = section { return b }
            return nil
        }
        let parentBlock = blocks.first(where: { $0.subject == "ex:Parent" })
        #expect(parentBlock != nil)
        let hasPredicate = parentBlock?.properties.contains(where: { $0.predicate == "owl:equivalentClass" })
        #expect(hasPredicate == true)
    }

    @Test("Simple inverse property is suppressed")
    func simpleInverseSuppressed() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:partOf a owl:ObjectProperty, owl:TransitiveProperty ;
            rdfs:label "part of" ; owl:inverseOf ex:hasPart .
        ex:hasPart a owl:ObjectProperty ;
            owl:inverseOf ex:partOf .
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
        // Only partOf should appear, hasPart is suppressed
        #expect(tabular?.rows.count == 1)
        #expect(tabular?.rows.first?.first == "ex:partOf")

        // hasPart should not appear as subject block either
        let blocks = hootDoc.sections.compactMap { section -> HootSubjectBlock? in
            if case .subjectBlock(let b) = section { return b }
            return nil
        }
        let hasPartBlock = blocks.first(where: { $0.subject == "ex:hasPart" })
        #expect(hasPartBlock == nil)
    }

    @Test("Annotation property table")
    func annotationPropertyTable() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:note a owl:AnnotationProperty ; rdfs:label "note" .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let tabular = hootDoc.sections.compactMap { section -> HootTabularSection? in
            if case .tabular(let t) = section, t.name == "AnnotationProperty" { return t }
            return nil
        }.first

        #expect(tabular != nil)
        #expect(tabular?.fields == ["iri", "label"])
        #expect(tabular?.rows.count == 1)
    }

    @Test("All OWL property characteristics")
    func propertyCharacteristics() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:symProp a owl:ObjectProperty, owl:SymmetricProperty ;
            rdfs:label "sym" .
        ex:asymProp a owl:ObjectProperty, owl:AsymmetricProperty ;
            rdfs:label "asym" .
        ex:reflProp a owl:ObjectProperty, owl:ReflexiveProperty ;
            rdfs:label "refl" .
        ex:irrefProp a owl:ObjectProperty, owl:IrreflexiveProperty ;
            rdfs:label "irref" .
        ex:funcProp a owl:ObjectProperty, owl:FunctionalProperty ;
            rdfs:label "func" .
        ex:invFuncProp a owl:ObjectProperty, owl:InverseFunctionalProperty ;
            rdfs:label "invFunc" .
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
        #expect(tabular?.rows.count == 6)

        // Verify characteristics field (index 3) for each
        let charIndex = tabular!.fields.firstIndex(of: "characteristics")!
        let characteristics = tabular!.rows.map { $0[charIndex] }
        #expect(characteristics.contains("symmetric"))
        #expect(characteristics.contains("asymmetric"))
        #expect(characteristics.contains("reflexive"))
        #expect(characteristics.contains("irreflexive"))
        #expect(characteristics.contains("functional"))
        #expect(characteristics.contains("inverseFunctional"))
    }

    @Test("Inline blank node in subject block")
    func inlineBlankNode() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .

        ex:A ex:has [
            a owl:Restriction ;
            owl:onProperty ex:p
        ] .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let blocks = hootDoc.sections.compactMap { section -> HootSubjectBlock? in
            if case .subjectBlock(let b) = section { return b }
            return nil
        }

        // ex:A should have an inline blank node, NOT a separate block for _:b0
        #expect(blocks.count == 1)
        #expect(blocks[0].subject == "ex:A")
        let hasProp = blocks[0].properties.first(where: { $0.predicate == "ex:has" })
        #expect(hasProp != nil)
        if case .inlineBlankNode(let props) = hasProp?.objects.first {
            #expect(props.count == 2)
        } else {
            #expect(Bool(false), "Expected inline blank node")
        }
    }

    @Test("Non-inline blank node when referenced multiple times")
    func nonInlineBlankNode() throws {
        let input = """
        @prefix ex: <http://example.org/> .

        ex:A ex:ref _:shared .
        ex:B ex:ref _:shared .
        _:shared ex:val "x" .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let blocks = hootDoc.sections.compactMap { section -> HootSubjectBlock? in
            if case .subjectBlock(let b) = section { return b }
            return nil
        }

        // All three subjects should have blocks since _:shared is referenced twice
        #expect(blocks.count == 3)
        let sharedBlock = blocks.first(where: { $0.subject == "_:shared" })
        #expect(sharedBlock != nil)
    }

    @Test("Subject block groups predicates with multiple objects")
    func multipleObjectsPerPredicate() throws {
        let input = """
        @prefix ex: <http://example.org/> .

        ex:A ex:tag "a", "b", "c" .
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
        #expect(blocks[0].properties.count == 1)
        #expect(blocks[0].properties[0].objects.count == 3)
    }

    @Test("rdf:type predicate becomes 'a' in subject block")
    func rdfTypeBecomesA() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:Toyota a ex:Company .
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
        #expect(blocks[0].properties.first?.predicate == "a")
    }

    @Test("Preserves subject order from original triples")
    func preservesSubjectOrder() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:C ex:val "3" .
        ex:A ex:val "1" .
        ex:B ex:val "2" .
        """
        let parser = TurtleParser()
        let turtleDoc = try parser.parse(input)
        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let blocks = hootDoc.sections.compactMap { section -> HootSubjectBlock? in
            if case .subjectBlock(let b) = section { return b }
            return nil
        }

        #expect(blocks.count == 3)
        #expect(blocks[0].subject == "ex:C")
        #expect(blocks[1].subject == "ex:A")
        #expect(blocks[2].subject == "ex:B")
    }

    @Test("Collection value is preserved")
    func collectionValue() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        ex:A ex:list ( ex:X ex:Y ex:Z ) .
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
        let listProp = blocks[0].properties.first(where: { $0.predicate == "ex:list" })
        #expect(listProp != nil)
        if case .collection(let items) = listProp?.objects.first {
            #expect(items.count == 3)
        } else {
            #expect(Bool(false), "Expected collection value")
        }
    }

    @Test("ObjectProperty table has correct field values")
    func objectPropertyFieldValues() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

        ex:locatedIn a owl:ObjectProperty, owl:TransitiveProperty ;
            rdfs:label "located in" ;
            rdfs:domain ex:Thing ;
            rdfs:range ex:Place .
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
        let row = tabular!.rows.first!
        let fields = tabular!.fields
        #expect(row[fields.firstIndex(of: "iri")!] == "ex:locatedIn")
        #expect(row[fields.firstIndex(of: "label")!] == "located in")
        #expect(row[fields.firstIndex(of: "inverse")!] == "")
        #expect(row[fields.firstIndex(of: "characteristics")!] == "transitive")
        #expect(row[fields.firstIndex(of: "domain")!] == "ex:Thing")
        #expect(row[fields.firstIndex(of: "range")!] == "ex:Place")
    }

    @Test("DataProperty table has correct field values")
    func dataPropertyFieldValues() throws {
        let input = """
        @prefix ex: <http://example.org/> .
        @prefix owl: <http://www.w3.org/2002/07/owl#> .
        @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

        ex:birthDate a owl:DatatypeProperty ;
            rdfs:label "birth date" ;
            rdfs:domain ex:Person ;
            rdfs:range xsd:date .
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
        #expect(tabular?.fields == ["iri", "label", "domain", "range"])
        let row = tabular!.rows.first!
        #expect(row[0] == "ex:birthDate")
        #expect(row[1] == "birth date")
        #expect(row[2] == "ex:Person")
        #expect(row[3] == "xsd:date")
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
