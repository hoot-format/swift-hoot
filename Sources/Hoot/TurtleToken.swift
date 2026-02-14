/// Lexical token from Turtle format.
public enum TurtleToken: Sendable, Equatable {
    /// `@prefix` directive
    case prefixDirective
    /// `@base` directive
    case baseDirective
    /// SPARQL-style `PREFIX` (case-insensitive)
    case sparqlPrefix
    /// SPARQL-style `BASE` (case-insensitive)
    case sparqlBase
    /// Full IRI between angle brackets (contents only, without `<>`)
    case iri(String)
    /// Prefixed name (e.g., `ex:Person` → prefix `"ex"`, local `"Person"`)
    case prefixedName(String, String)
    /// Blank node label (e.g., `_:b0` → `"b0"`)
    case blankNodeLabel(String)
    /// String literal contents (without surrounding quotes)
    case stringLiteral(String)
    /// Language tag (e.g., `@en` → `"en"`, without `@`)
    case langTag(String)
    /// Datatype separator `^^`
    case hatHat
    /// Integer literal (e.g., `"42"`)
    case integer(String)
    /// Decimal literal (e.g., `"3.14"`)
    case decimal(String)
    /// Double literal (e.g., `"1.0e5"`)
    case double(String)
    /// Boolean `true`
    case booleanTrue
    /// Boolean `false`
    case booleanFalse
    /// `a` shorthand for `rdf:type`
    case a
    /// `.` statement terminator
    case dot
    /// `;` predicate separator
    case semicolon
    /// `,` object separator
    case comma
    /// `[` open bracket
    case openBracket
    /// `]` close bracket
    case closeBracket
    /// `(` open parenthesis
    case openParen
    /// `)` close parenthesis
    case closeParen
}
