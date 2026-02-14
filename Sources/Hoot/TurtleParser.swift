/// Error during Turtle parsing.
public struct TurtleParserError: Error, Sendable {
    public let message: String
    public let tokenIndex: Int

    public init(_ message: String, at tokenIndex: Int) {
        self.message = message
        self.tokenIndex = tokenIndex
    }
}

/// Parses Turtle format text into a `TurtleDocument`.
public struct TurtleParser: Sendable {

    public init() {}

    /// Parse a Turtle format string into a `TurtleDocument`.
    public func parse(_ input: String) throws -> TurtleDocument {
        let lexer = TurtleLexer()
        let tokens = try lexer.tokenize(input)
        var state = ParserState(tokens: tokens)
        return try state.parseDocument()
    }
}

// MARK: - Parser State

private struct ParserState {
    let tokens: [TurtleToken]
    var pos: Int = 0
    var prefixes: [TurtlePrefixMapping] = []
    var base: String? = nil
    var triples: [RDFTriple] = []
    var blankNodeCounter: Int = 0

    var isAtEnd: Bool { pos >= tokens.count }

    func peek() -> TurtleToken? {
        guard pos < tokens.count else { return nil }
        return tokens[pos]
    }

    mutating func advance() -> TurtleToken {
        let token = tokens[pos]
        pos += 1
        return token
    }

    mutating func expect(_ expected: TurtleToken) throws {
        guard !isAtEnd else {
            throw TurtleParserError("Expected \(expected), got end of input", at: pos)
        }
        let token = advance()
        guard token == expected else {
            throw TurtleParserError("Expected \(expected), got \(token)", at: pos - 1)
        }
    }

    mutating func freshBlankNode() -> String {
        let label = "b\(blankNodeCounter)"
        blankNodeCounter += 1
        return label
    }

    // MARK: - Document

    mutating func parseDocument() throws -> TurtleDocument {
        while !isAtEnd {
            guard let token = peek() else { break }

            switch token {
            case .prefixDirective:
                try parsePrefixDirective()
            case .sparqlPrefix:
                try parseSparqlPrefix()
            case .baseDirective:
                try parseBaseDirective()
            case .sparqlBase:
                try parseSparqlBase()
            default:
                try parseTriplesStatement()
            }
        }

        return TurtleDocument(
            prefixes: prefixes,
            base: base,
            triples: triples
        )
    }

    // MARK: - Prefix / Base

    mutating func parsePrefixDirective() throws {
        _ = advance() // @prefix
        guard case .prefixedName(let name, let local) = peek(), local.isEmpty else {
            throw TurtleParserError("Expected prefix name after @prefix", at: pos)
        }
        _ = advance()
        guard case .iri(let iri) = peek() else {
            throw TurtleParserError("Expected IRI after prefix name", at: pos)
        }
        _ = advance()
        try expect(.dot)
        prefixes.append(TurtlePrefixMapping(name: name, iri: iri))
    }

    mutating func parseSparqlPrefix() throws {
        _ = advance() // PREFIX
        guard case .prefixedName(let name, let local) = peek(), local.isEmpty else {
            throw TurtleParserError("Expected prefix name after PREFIX", at: pos)
        }
        _ = advance()
        guard case .iri(let iri) = peek() else {
            throw TurtleParserError("Expected IRI after prefix name", at: pos)
        }
        _ = advance()
        // SPARQL-style PREFIX does not end with dot
        prefixes.append(TurtlePrefixMapping(name: name, iri: iri))
    }

    mutating func parseBaseDirective() throws {
        _ = advance() // @base
        guard case .iri(let iri) = peek() else {
            throw TurtleParserError("Expected IRI after @base", at: pos)
        }
        _ = advance()
        try expect(.dot)
        base = iri
    }

    mutating func parseSparqlBase() throws {
        _ = advance() // BASE
        guard case .iri(let iri) = peek() else {
            throw TurtleParserError("Expected IRI after BASE", at: pos)
        }
        _ = advance()
        base = iri
    }

    // MARK: - Triples

    mutating func parseTriplesStatement() throws {
        let subject = try parseSubject()

        // Handle blank node property list as subject with no further predicates
        if peek() == .dot {
            _ = advance()
            return
        }

        try parsePredicateObjectList(subject: subject)
        try expect(.dot)
    }

    mutating func parsePredicateObjectList(subject: RDFNode) throws {
        try parsePredicateObjectPair(subject: subject)

        while peek() == .semicolon {
            _ = advance() // skip ';'
            // Allow trailing semicolon before '.' or ']'
            guard let next = peek(), next != .dot && next != .closeBracket else { break }
            try parsePredicateObjectPair(subject: subject)
        }
    }

    mutating func parsePredicateObjectPair(subject: RDFNode) throws {
        let predicate = try parsePredicate()
        try parseObjectList(subject: subject, predicate: predicate)
    }

    mutating func parseObjectList(subject: RDFNode, predicate: RDFNode) throws {
        let obj = try parseObject()
        triples.append(RDFTriple(subject: subject, predicate: predicate, object: obj))

        while peek() == .comma {
            _ = advance() // skip ','
            let obj = try parseObject()
            triples.append(RDFTriple(subject: subject, predicate: predicate, object: obj))
        }
    }

    // MARK: - Subject

    mutating func parseSubject() throws -> RDFNode {
        guard let token = peek() else {
            throw TurtleParserError("Expected subject, got end of input", at: pos)
        }

        switch token {
        case .iri(let iri):
            _ = advance()
            return .iri(iri)
        case .prefixedName(let prefix, let local):
            _ = advance()
            return .prefixedName(prefix: prefix, local: local)
        case .blankNodeLabel(let label):
            _ = advance()
            return .blankNode(label)
        case .openBracket:
            return try parseBlankNodePropertyList()
        case .openParen:
            return try parseCollectionAsSubject()
        default:
            throw TurtleParserError("Expected subject, got \(token)", at: pos)
        }
    }

    // MARK: - Predicate

    mutating func parsePredicate() throws -> RDFNode {
        guard let token = peek() else {
            throw TurtleParserError("Expected predicate, got end of input", at: pos)
        }

        switch token {
        case .a:
            _ = advance()
            return .prefixedName(prefix: "rdf", local: "type")
        case .iri(let iri):
            _ = advance()
            return .iri(iri)
        case .prefixedName(let prefix, let local):
            _ = advance()
            return .prefixedName(prefix: prefix, local: local)
        default:
            throw TurtleParserError("Expected predicate, got \(token)", at: pos)
        }
    }

    // MARK: - Object

    mutating func parseObject() throws -> RDFNode {
        guard let token = peek() else {
            throw TurtleParserError("Expected object, got end of input", at: pos)
        }

        switch token {
        case .iri(let iri):
            _ = advance()
            return .iri(iri)
        case .prefixedName(let prefix, let local):
            _ = advance()
            return .prefixedName(prefix: prefix, local: local)
        case .blankNodeLabel(let label):
            _ = advance()
            return .blankNode(label)
        case .stringLiteral(let str):
            _ = advance()
            return try parseLiteral(str)
        case .integer(let num):
            _ = advance()
            return .number(num)
        case .decimal(let num):
            _ = advance()
            return .number(num)
        case .double(let num):
            _ = advance()
            return .number(num)
        case .booleanTrue:
            _ = advance()
            return .boolean(true)
        case .booleanFalse:
            _ = advance()
            return .boolean(false)
        case .openBracket:
            return try parseBlankNodePropertyList()
        case .openParen:
            return try parseCollection()
        default:
            throw TurtleParserError("Expected object, got \(token)", at: pos)
        }
    }

    // MARK: - Literal

    mutating func parseLiteral(_ value: String) throws -> RDFNode {
        if peek() == .hatHat {
            _ = advance() // skip ^^
            let datatype = try parseObject()
            return .literal(value, datatype: datatype, language: nil)
        } else if case .langTag(let lang) = peek() {
            _ = advance()
            return .literal(value, datatype: nil, language: lang)
        } else {
            return .literal(value, datatype: nil, language: nil)
        }
    }

    // MARK: - Blank Node Property List

    mutating func parseBlankNodePropertyList() throws -> RDFNode {
        _ = advance() // skip '['

        let label = freshBlankNode()
        let subject = RDFNode.blankNode(label)

        // Handle empty blank node: []
        if peek() == .closeBracket {
            _ = advance()
            return subject
        }

        try parsePredicateObjectList(subject: subject)
        try expect(.closeBracket)

        return subject
    }

    // MARK: - Collection

    mutating func parseCollection() throws -> RDFNode {
        _ = advance() // skip '('

        var items: [RDFNode] = []
        while peek() != .closeParen {
            guard peek() != nil else {
                throw TurtleParserError("Unterminated collection", at: pos)
            }
            items.append(try parseObject())
        }
        _ = advance() // skip ')'

        return .collection(items)
    }

    mutating func parseCollectionAsSubject() throws -> RDFNode {
        // Collections as subjects need to be expanded to blank node chains
        let collection = try parseCollection()

        // Generate a blank node to represent the collection
        guard case .collection(let items) = collection else {
            return collection
        }

        if items.isEmpty {
            return .prefixedName(prefix: "rdf", local: "nil")
        }

        // Build rdf:first/rdf:rest chain
        let headLabel = freshBlankNode()
        var currentLabel = headLabel

        for (index, item) in items.enumerated() {
            let current = RDFNode.blankNode(currentLabel)
            triples.append(RDFTriple(
                subject: current,
                predicate: .prefixedName(prefix: "rdf", local: "first"),
                object: item
            ))

            if index < items.count - 1 {
                let nextLabel = freshBlankNode()
                triples.append(RDFTriple(
                    subject: current,
                    predicate: .prefixedName(prefix: "rdf", local: "rest"),
                    object: .blankNode(nextLabel)
                ))
                currentLabel = nextLabel
            } else {
                triples.append(RDFTriple(
                    subject: current,
                    predicate: .prefixedName(prefix: "rdf", local: "rest"),
                    object: .prefixedName(prefix: "rdf", local: "nil")
                ))
            }
        }

        return .blankNode(headLabel)
    }
}
