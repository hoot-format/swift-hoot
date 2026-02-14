/// An RDF triple (subject-predicate-object statement).
public struct RDFTriple: Sendable, Equatable {
    public var subject: RDFNode
    public var predicate: RDFNode
    public var object: RDFNode

    public init(subject: RDFNode, predicate: RDFNode, object: RDFNode) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
    }
}

/// An RDF node (can appear in subject, predicate, or object position).
public indirect enum RDFNode: Sendable, Equatable {
    /// Full IRI (e.g., `"http://example.org/Person"`).
    case iri(String)

    /// Prefixed name (e.g., prefix: `"ex"`, local: `"Person"`).
    case prefixedName(prefix: String, local: String)

    /// Blank node (e.g., `"b0"`).
    case blankNode(String)

    /// String literal with optional datatype or language tag.
    case literal(String, datatype: RDFNode?, language: String?)

    /// Numeric literal (integer or decimal as string).
    case number(String)

    /// Boolean literal.
    case boolean(Bool)

    /// RDF collection (ordered list from Turtle `(...)` syntax).
    case collection([RDFNode])
}

/// The result of parsing a Turtle document.
public struct TurtleDocument: Sendable, Equatable {
    /// Prefix mappings declared in the file.
    public var prefixes: [TurtlePrefixMapping]

    /// Base IRI, if declared.
    public var base: String?

    /// Parsed triples.
    public var triples: [RDFTriple]

    public init(
        prefixes: [TurtlePrefixMapping] = [],
        base: String? = nil,
        triples: [RDFTriple] = []
    ) {
        self.prefixes = prefixes
        self.base = base
        self.triples = triples
    }
}

/// A prefix mapping from a Turtle document.
public struct TurtlePrefixMapping: Sendable, Equatable {
    public var name: String
    public var iri: String

    public init(name: String, iri: String) {
        self.name = name
        self.iri = iri
    }
}
