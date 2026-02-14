/// A HOOT document representing an ontology in compact form.
///
/// HOOT (Hierarchical Ontology-Optimized Tokens) encodes OWL ontology data
/// using indentation-based class hierarchy, tabular property declarations,
/// and inline disjoint sets.
public struct HootDocument: Sendable, Equatable {

    /// Namespace prefix declarations (e.g., `["ex": "http://example.org/"]`).
    public var prefixes: [(short: String, iri: String)]

    /// Root-level classes (children of `owl:Thing`).
    public var classes: [HootClass]

    /// Tabular and inline sections (properties, disjoints, etc.).
    public var sections: [HootSection]

    public init(
        prefixes: [(short: String, iri: String)] = [],
        classes: [HootClass] = [],
        sections: [HootSection] = []
    ) {
        self.prefixes = prefixes
        self.classes = classes
        self.sections = sections
    }

    public static func == (lhs: HootDocument, rhs: HootDocument) -> Bool {
        guard lhs.prefixes.count == rhs.prefixes.count else { return false }
        for (l, r) in zip(lhs.prefixes, rhs.prefixes) {
            guard l.short == r.short, l.iri == r.iri else { return false }
        }
        return lhs.classes == rhs.classes && lhs.sections == rhs.sections
    }
}

/// A class in the ontology hierarchy.
///
/// Children represent `rdfs:subClassOf` relationships.
public struct HootClass: Sendable, Equatable {

    /// Class name (short form, e.g., `"Person"` not `"ex:Person"`).
    public var name: String

    /// Subclasses of this class.
    public var children: [HootClass]

    public init(name: String, children: [HootClass] = []) {
        self.name = name
        self.children = children
    }
}

/// A section in a HOOT document.
public enum HootSection: Sendable, Equatable {
    /// Tabular section with header fields and data rows.
    case tabular(HootTabularSection)

    /// Inline section with grouped values.
    case inline(HootInlineSection)
}

/// A tabular section (e.g., `ObjectProperty{iri,inverse,characteristics}:`).
public struct HootTabularSection: Sendable, Equatable {

    /// Section name (e.g., `"ObjectProperty"`).
    public var name: String

    /// Field names declared in the header.
    public var fields: [String]

    /// Data rows. Each row is an array of field values.
    /// Empty strings represent omitted fields.
    public var rows: [[String]]

    public init(name: String, fields: [String], rows: [[String]] = []) {
        self.name = name
        self.fields = fields
        self.rows = rows
    }
}

/// An inline section (e.g., `Disjoint: {Person,Organization},{Person,Place}`).
public struct HootInlineSection: Sendable, Equatable {

    /// Section name (e.g., `"Disjoint"`).
    public var name: String

    /// Groups of values. Each group is a set of class names.
    public var groups: [[String]]

    public init(name: String, groups: [[String]] = []) {
        self.name = name
        self.groups = groups
    }
}
