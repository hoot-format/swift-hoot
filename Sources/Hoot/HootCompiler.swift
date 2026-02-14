/// Compiles a `TurtleDocument` (raw RDF triples) into a `HootDocument`
/// by detecting OWL patterns (class hierarchy, property tables, disjoint sets).
public struct HootCompiler: Sendable {

    public init() {}

    /// Compile a parsed Turtle document into a HOOT document.
    public func compile(_ document: TurtleDocument) -> HootDocument {
        let prefixes = document.prefixes.map {
            HootPrefix(name: $0.name, iri: $0.iri)
        }

        var index = TripleIndex(triples: document.triples, prefixes: document.prefixes)

        let classHierarchy = index.buildClassHierarchy()
        let objectProperties = index.buildTabularSection(
            type: "ObjectProperty",
            typeIRI: "owl:ObjectProperty"
        )
        let dataProperties = index.buildTabularSection(
            type: "DataProperty",
            typeIRI: "owl:DatatypeProperty"
        )
        let annotationProperties = index.buildTabularSection(
            type: "AnnotationProperty",
            typeIRI: "owl:AnnotationProperty"
        )
        let disjoint = index.buildDisjointSection()
        let subjectBlocks = index.buildSubjectBlocks()

        var sections: [HootSection] = []

        if let hierarchy = classHierarchy {
            sections.append(.classHierarchy(hierarchy))
        }
        if let objProps = objectProperties {
            sections.append(.tabular(objProps))
        }
        if let dataProps = dataProperties {
            sections.append(.tabular(dataProps))
        }
        if let annProps = annotationProperties {
            sections.append(.tabular(annProps))
        }
        if let disj = disjoint {
            sections.append(.disjoint(disj))
        }
        for block in subjectBlocks {
            sections.append(.subjectBlock(block))
        }

        return HootDocument(prefixes: prefixes, sections: sections)
    }
}

// MARK: - Well-known IRIs

private enum WellKnown {
    static let rdfType = "rdf:type"
    static let rdfsSubClassOf = "rdfs:subClassOf"
    static let rdfsLabel = "rdfs:label"
    static let rdfsDomain = "rdfs:domain"
    static let rdfsRange = "rdfs:range"
    static let owlClass = "owl:Class"
    static let owlThing = "owl:Thing"
    static let owlObjectProperty = "owl:ObjectProperty"
    static let owlDatatypeProperty = "owl:DatatypeProperty"
    static let owlAnnotationProperty = "owl:AnnotationProperty"
    static let owlInverseOf = "owl:inverseOf"
    static let owlAllDisjointClasses = "owl:AllDisjointClasses"
    static let owlMembers = "owl:members"

    static let characteristicTypes: [String: String] = [
        "owl:TransitiveProperty": "transitive",
        "owl:SymmetricProperty": "symmetric",
        "owl:AsymmetricProperty": "asymmetric",
        "owl:ReflexiveProperty": "reflexive",
        "owl:IrreflexiveProperty": "irreflexive",
        "owl:FunctionalProperty": "functional",
        "owl:InverseFunctionalProperty": "inverseFunctional",
    ]
}

// MARK: - Triple Index

private struct TripleIndex {
    /// All predicate-object pairs grouped by subject string key.
    var subjectIndex: [String: [(predicate: String, object: RDFNode)]]

    /// Subjects consumed by compact sections (should not appear as subject blocks).
    var consumed: Set<String>

    /// Prefix mappings for resolving prefixed names.
    let prefixes: [TurtlePrefixMapping]

    /// Blank node reference counts (how many times each blank node appears in object position).
    var blankNodeRefCounts: [String: Int]

    /// The original triples for preserving order.
    let triples: [RDFTriple]

    init(triples: [RDFTriple], prefixes: [TurtlePrefixMapping]) {
        self.triples = triples
        self.prefixes = prefixes
        self.consumed = []
        self.subjectIndex = [:]
        self.blankNodeRefCounts = [:]

        for triple in triples {
            let subjectKey = Self.nodeKey(triple.subject)
            subjectIndex[subjectKey, default: []].append(
                (predicate: Self.nodeKey(triple.predicate), object: triple.object)
            )

            if case .blankNode(let label) = triple.object {
                blankNodeRefCounts[label, default: 0] += 1
            }

            // Count blank nodes inside collections too
            if case .collection(let items) = triple.object {
                for item in items {
                    if case .blankNode(let label) = item {
                        blankNodeRefCounts[label, default: 0] += 1
                    }
                }
            }
        }
    }

    /// Convert an RDFNode to its string key for indexing.
    static func nodeKey(_ node: RDFNode) -> String {
        switch node {
        case .iri(let iri):
            return iri
        case .prefixedName(let prefix, let local):
            return prefix.isEmpty ? ":\(local)" : "\(prefix):\(local)"
        case .blankNode(let label):
            return "_:\(label)"
        case .literal(let value, _, _):
            return value
        case .number(let num):
            return num
        case .boolean(let val):
            return val ? "true" : "false"
        case .collection:
            return "(collection)"
        }
    }

    /// Get all type assertions for a subject.
    func getTypes(_ subject: String) -> [String] {
        guard let pairs = subjectIndex[subject] else { return [] }
        return pairs.compactMap { pair in
            pair.predicate == WellKnown.rdfType ? Self.nodeKey(pair.object) : nil
        }
    }

    /// Get first value for a predicate on a subject.
    func getValue(_ subject: String, predicate: String) -> String? {
        guard let pairs = subjectIndex[subject] else { return nil }
        return pairs.first(where: { $0.predicate == predicate }).map { Self.nodeKey($0.object) }
    }

    /// Get the raw object node for a predicate on a subject.
    func getObjectNode(_ subject: String, predicate: String) -> RDFNode? {
        guard let pairs = subjectIndex[subject] else { return nil }
        return pairs.first(where: { $0.predicate == predicate })?.object
    }

    // MARK: - Class Hierarchy

    mutating func buildClassHierarchy() -> HootClassHierarchy? {
        // Find all subjects that have rdf:type owl:Class
        var classSubjects: [String] = []
        for (subject, _) in subjectIndex {
            let types = getTypes(subject)
            if types.contains(WellKnown.owlClass) {
                classSubjects.append(subject)
            }
        }

        guard !classSubjects.isEmpty else { return nil }

        // Build parent-child map
        var parentToChildren: [String: [String]] = [:]
        var classLabels: [String: String] = [:]
        var classExtraProperties: [String: [(predicate: String, object: RDFNode)]] = [:]

        let knownClassPredicates: Set<String> = [
            WellKnown.rdfType, WellKnown.rdfsSubClassOf, WellKnown.rdfsLabel,
        ]

        for subject in classSubjects {
            let parent = getValue(subject, predicate: WellKnown.rdfsSubClassOf) ?? WellKnown.owlThing
            parentToChildren[parent, default: []].append(subject)

            if let label = getValue(subject, predicate: WellKnown.rdfsLabel) {
                classLabels[subject] = label
            }

            // Check for extra properties
            if let pairs = subjectIndex[subject] {
                let extras = pairs.filter { !knownClassPredicates.contains($0.predicate) }
                if !extras.isEmpty {
                    classExtraProperties[subject] = extras
                }
            }
        }

        // Build tree recursively
        func buildChildren(of parent: String) -> [HootClass] {
            guard let children = parentToChildren[parent] else { return [] }
            return children.sorted().map { child in
                let label = classLabels[child]
                let subChildren = buildChildren(of: child)
                return HootClass(iri: child, label: label, children: subChildren)
            }
        }

        let topLevel = buildChildren(of: WellKnown.owlThing)
        guard !topLevel.isEmpty else { return nil }

        // Mark classes as consumed
        for subject in classSubjects {
            if classExtraProperties[subject] != nil {
                // Partially consumed: class hierarchy captures the class,
                // but extra properties need a subject block.
                // Replace the full triple set with only the extras.
                subjectIndex[subject] = classExtraProperties[subject]
            } else {
                consumed.insert(subject)
            }
        }

        return HootClassHierarchy(root: WellKnown.owlThing, classes: topLevel)
    }

    // MARK: - Tabular Sections

    mutating func buildTabularSection(type: String, typeIRI: String) -> HootTabularSection? {
        var propertySubjects: [String] = []
        for (subject, _) in subjectIndex {
            let types = getTypes(subject)
            if types.contains(typeIRI) {
                propertySubjects.append(subject)
            }
        }

        guard !propertySubjects.isEmpty else { return nil }

        // Pre-scan: identify simple inverse properties (only have type + inverseOf)
        var simpleInverses: Set<String> = []
        for subject in propertySubjects {
            if let pairs = subjectIndex[subject] {
                let isSimple = pairs.allSatisfy { pair in
                    pair.predicate == WellKnown.rdfType ||
                    pair.predicate == WellKnown.owlInverseOf
                }
                if isSimple {
                    // Check if this property's inverse is a full property declaration
                    if let inverse = getValue(subject, predicate: WellKnown.owlInverseOf),
                       propertySubjects.contains(inverse) {
                        simpleInverses.insert(subject)
                    }
                }
            }
        }

        // Filter out simple inverses and sort
        propertySubjects = propertySubjects.filter { !simpleInverses.contains($0) }
        propertySubjects.sort()

        guard !propertySubjects.isEmpty else {
            // All were simple inverses, consume them and return nil
            for subject in simpleInverses { consumed.insert(subject) }
            return nil
        }

        // Determine fields based on type
        let fields: [String]
        switch type {
        case "ObjectProperty":
            fields = ["iri", "label", "inverse", "characteristics", "domain", "range"]
        case "DataProperty":
            fields = ["iri", "label", "domain", "range"]
        case "AnnotationProperty":
            fields = ["iri", "label"]
        default:
            fields = ["iri", "label"]
        }

        var rows: [[String]] = []

        for subject in propertySubjects {
            var row: [String] = []

            for field in fields {
                switch field {
                case "iri":
                    row.append(subject)
                case "label":
                    row.append(getValue(subject, predicate: WellKnown.rdfsLabel) ?? "")
                case "inverse":
                    row.append(getValue(subject, predicate: WellKnown.owlInverseOf) ?? "")
                case "characteristics":
                    let types = getTypes(subject)
                    let characteristics = types.compactMap { WellKnown.characteristicTypes[$0] }
                    row.append(characteristics.first ?? "")
                case "domain":
                    row.append(getValue(subject, predicate: WellKnown.rdfsDomain) ?? "")
                case "range":
                    row.append(getValue(subject, predicate: WellKnown.rdfsRange) ?? "")
                default:
                    row.append("")
                }
            }

            rows.append(row)
            consumed.insert(subject)
        }

        // Consume simple inverses
        for subject in simpleInverses { consumed.insert(subject) }

        return HootTabularSection(name: type, fields: fields, rows: rows)
    }

    // MARK: - Disjoint Section

    mutating func buildDisjointSection() -> HootDisjointSection? {
        var groups: [[String]] = []

        for (subject, _) in subjectIndex {
            let types = getTypes(subject)
            guard types.contains(WellKnown.owlAllDisjointClasses) else { continue }

            if let membersNode = getObjectNode(subject, predicate: WellKnown.owlMembers),
               case .collection(let items) = membersNode {
                let group = items.map { Self.nodeKey($0) }
                groups.append(group)
            }

            consumed.insert(subject)
        }

        guard !groups.isEmpty else { return nil }

        return HootDisjointSection(groups: groups)
    }

    // MARK: - Subject Blocks

    mutating func buildSubjectBlocks() -> [HootSubjectBlock] {
        var blocks: [HootSubjectBlock] = []

        // Preserve order of first appearance
        var seen: Set<String> = []
        var orderedSubjects: [String] = []
        for triple in triples {
            let key = Self.nodeKey(triple.subject)
            if !seen.contains(key) {
                seen.insert(key)
                orderedSubjects.append(key)
            }
        }

        for subject in orderedSubjects {
            guard !consumed.contains(subject) else { continue }

            // Skip blank nodes that are inlineable (referenced exactly once as object)
            if subject.hasPrefix("_:") {
                let label = String(subject.dropFirst(2))
                if (blankNodeRefCounts[label] ?? 0) == 1 {
                    continue
                }
            }

            guard let pairs = subjectIndex[subject] else { continue }

            var properties: [HootProperty] = []
            // Group by predicate to collect multiple objects
            var predicateOrder: [String] = []
            var predicateObjects: [String: [HootValue]] = [:]

            for pair in pairs {
                if predicateObjects[pair.predicate] == nil {
                    predicateOrder.append(pair.predicate)
                }
                let value = convertToHootValue(pair.object)
                predicateObjects[pair.predicate, default: []].append(value)
            }

            for predicate in predicateOrder {
                let objects = predicateObjects[predicate] ?? []
                let pred = predicate == WellKnown.rdfType ? "a" : predicate
                properties.append(HootProperty(predicate: pred, objects: objects))
            }

            blocks.append(HootSubjectBlock(subject: subject, properties: properties))
        }

        return blocks
    }

    // MARK: - Value Conversion

    func convertToHootValue(_ node: RDFNode) -> HootValue {
        switch node {
        case .iri(let iri):
            return .iri(iri)
        case .prefixedName(let prefix, let local):
            let key = prefix.isEmpty ? ":\(local)" : "\(prefix):\(local)"
            return .iri(key)
        case .blankNode(let label):
            // Check if this blank node should be inlined
            if (blankNodeRefCounts[label] ?? 0) == 1,
               let pairs = subjectIndex["_:\(label)"] {
                let properties = pairs.map { pair -> HootProperty in
                    let pred = pair.predicate == WellKnown.rdfType ? "a" : pair.predicate
                    let objects = [convertToHootValue(pair.object)]
                    return HootProperty(predicate: pred, objects: objects)
                }
                return .inlineBlankNode(properties)
            }
            return .blankNode(label)
        case .literal(let value, let datatype, let language):
            if let lang = language {
                return .literal(value, language: lang)
            }
            if let dt = datatype {
                let dtStr = Self.nodeKey(dt)
                return .literal(value, datatype: dtStr)
            }
            return .literal(value)
        case .number(let num):
            return .number(num)
        case .boolean(let val):
            return .boolean(val)
        case .collection(let items):
            return .collection(items.map { convertToHootValue($0) })
        }
    }
}
