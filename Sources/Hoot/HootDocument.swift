/// A HOOT document representing an RDF graph in compact form.
///
/// HOOT (Hierarchical Ontology-Optimized Tokens) encodes OWL ontology data
/// using indentation-based class hierarchy, tabular property declarations,
/// inline disjoint sets, and general-purpose subject blocks.
public struct HootDocument: Sendable, Equatable {

    /// Namespace prefix declarations (e.g., `[("ex", "http://example.org/")]`).
    public var prefixes: [HootPrefix]

    /// Sections in document order.
    public var sections: [HootSection]

    public init(
        prefixes: [HootPrefix] = [],
        sections: [HootSection] = []
    ) {
        self.prefixes = prefixes
        self.sections = sections
    }
}

/// A prefix declaration.
public struct HootPrefix: Sendable, Equatable {
    /// Short prefix name (e.g., `"ex"`).
    public var name: String

    /// Full IRI (e.g., `"http://example.org/"`).
    public var iri: String

    public init(name: String, iri: String) {
        self.name = name
        self.iri = iri
    }
}

/// A section in a HOOT document.
public enum HootSection: Sendable, Equatable {
    /// Class hierarchy (compact OWL pattern).
    case classHierarchy(HootClassHierarchy)

    /// Tabular section (e.g., ObjectProperty, DataProperty).
    case tabular(HootTabularSection)

    /// Disjoint class sets (compact OWL pattern).
    case disjoint(HootDisjointSection)

    /// General-purpose subject block.
    case subjectBlock(HootSubjectBlock)
}

// MARK: - Class Hierarchy

/// A class hierarchy rooted at a given class (typically `owl:Thing`).
public struct HootClassHierarchy: Sendable, Equatable {
    /// Root class IRI (e.g., `"owl:Thing"`).
    public var root: String

    /// Top-level classes under the root.
    public var classes: [HootClass]

    public init(root: String = "owl:Thing", classes: [HootClass] = []) {
        self.root = root
        self.classes = classes
    }
}

/// A class in the ontology hierarchy.
public struct HootClass: Sendable, Equatable {
    /// Class IRI (e.g., `"ex:Person"` in lossless, `"Person"` in compact).
    public var iri: String

    /// Explicit label. `nil` means derive from IRI local name.
    public var label: String?

    /// Subclasses.
    public var children: [HootClass]

    public init(iri: String, label: String? = nil, children: [HootClass] = []) {
        self.iri = iri
        self.label = label
        self.children = children
    }
}

// MARK: - Tabular Section

/// A tabular section (e.g., `ObjectProperty{iri,label,inverse,...}:`).
public struct HootTabularSection: Sendable, Equatable {
    /// Section type name (e.g., `"ObjectProperty"`, `"DataProperty"`).
    public var name: String

    /// Field names declared in the header.
    public var fields: [String]

    /// Data rows. Each row is an array of field values.
    public var rows: [[String]]

    public init(name: String, fields: [String], rows: [[String]] = []) {
        self.name = name
        self.fields = fields
        self.rows = rows
    }
}

// MARK: - Disjoint Section

/// Disjoint class declarations.
public struct HootDisjointSection: Sendable, Equatable {
    /// Groups of mutually disjoint classes.
    /// Each group is a list of class IRIs.
    public var groups: [[String]]

    public init(groups: [[String]] = []) {
        self.groups = groups
    }
}

// MARK: - Subject Block

/// A general-purpose subject block for arbitrary triples.
public struct HootSubjectBlock: Sendable, Equatable {
    /// Subject IRI or blank node label.
    public var subject: String

    /// Predicate-object pairs.
    public var properties: [HootProperty]

    public init(subject: String, properties: [HootProperty] = []) {
        self.subject = subject
        self.properties = properties
    }
}

/// A predicate-object pair in a subject block.
public struct HootProperty: Sendable, Equatable {
    /// Predicate IRI (or `"a"` for `rdf:type`).
    public var predicate: String

    /// Object values.
    public var objects: [HootValue]

    public init(predicate: String, objects: [HootValue]) {
        self.predicate = predicate
        self.objects = objects
    }
}

/// An RDF value (object position in a triple).
public indirect enum HootValue: Sendable, Equatable {
    /// IRI reference (prefixed or full).
    case iri(String)

    /// String literal, optionally with datatype or language tag.
    case literal(String, datatype: String? = nil, language: String? = nil)

    /// Numeric literal.
    case number(String)

    /// Boolean literal.
    case boolean(Bool)

    /// Blank node reference.
    case blankNode(String)

    /// Inline anonymous blank node with properties.
    case inlineBlankNode([HootProperty])

    /// RDF collection (list).
    case collection([HootValue])
}
