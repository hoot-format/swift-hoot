import Testing
@testable import Hoot

@Suite("TurtleLexer")
struct TurtleLexerTests {

    let lexer = TurtleLexer()

    // MARK: - IRI

    @Test("Tokenizes full IRI")
    func fullIRI() throws {
        let tokens = try lexer.tokenize("<http://example.org/>")
        #expect(tokens == [.iri("http://example.org/")])
    }

    @Test("Tokenizes IRI with unicode escape")
    func iriUnicodeEscape() throws {
        let tokens = try lexer.tokenize("<http://example.org/\\u0041>")
        #expect(tokens == [.iri("http://example.org/A")])
    }

    @Test("Throws on unterminated IRI")
    func unterminatedIRI() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("<http://example.org/")
        }
    }

    @Test("Throws on unterminated IRI escape")
    func unterminatedIRIEscape() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("<http://example.org/\\")
        }
    }

    // MARK: - String Literals

    @Test("Tokenizes double-quoted string")
    func doubleQuotedString() throws {
        let tokens = try lexer.tokenize("\"hello world\"")
        #expect(tokens == [.stringLiteral("hello world")])
    }

    @Test("Tokenizes single-quoted string")
    func singleQuotedString() throws {
        let tokens = try lexer.tokenize("'hello world'")
        #expect(tokens == [.stringLiteral("hello world")])
    }

    @Test("Tokenizes empty double-quoted string")
    func emptyDoubleQuotedString() throws {
        let tokens = try lexer.tokenize("\"\"")
        #expect(tokens == [.stringLiteral("")])
    }

    @Test("Tokenizes empty single-quoted string")
    func emptySingleQuotedString() throws {
        let tokens = try lexer.tokenize("''")
        #expect(tokens == [.stringLiteral("")])
    }

    @Test("Tokenizes long double-quoted string")
    func longDoubleQuotedString() throws {
        let tokens = try lexer.tokenize("\"\"\"line1\nline2\"\"\"")
        #expect(tokens == [.stringLiteral("line1\nline2")])
    }

    @Test("Tokenizes long single-quoted string")
    func longSingleQuotedString() throws {
        let tokens = try lexer.tokenize("'''line1\nline2'''")
        #expect(tokens == [.stringLiteral("line1\nline2")])
    }

    @Test("Tokenizes empty long double-quoted string")
    func emptyLongDoubleQuotedString() throws {
        let tokens = try lexer.tokenize("\"\"\"\"\"\"")
        #expect(tokens == [.stringLiteral("")])
    }

    @Test("Tokenizes empty long single-quoted string")
    func emptyLongSingleQuotedString() throws {
        let tokens = try lexer.tokenize("''''''")
        #expect(tokens == [.stringLiteral("")])
    }

    @Test("Throws on unterminated double-quoted string")
    func unterminatedDoubleString() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"hello")
        }
    }

    @Test("Throws on unterminated single-quoted string")
    func unterminatedSingleString() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("'hello")
        }
    }

    @Test("Throws on unterminated long string")
    func unterminatedLongString() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"\"\"hello")
        }
    }

    @Test("Throws on newline in short string")
    func newlineInShortString() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"hello\nworld\"")
        }
    }

    // MARK: - Escape Sequences

    @Test("Handles all standard escape sequences")
    func standardEscapes() throws {
        let tokens = try lexer.tokenize("\"\\\\\\\"\\n\\r\\t\"")
        #expect(tokens == [.stringLiteral("\\\"\n\r\t")])
    }

    @Test("Handles single quote escape in single-quoted string")
    func singleQuoteEscape() throws {
        let tokens = try lexer.tokenize("'don\\'t'")
        #expect(tokens == [.stringLiteral("don't")])
    }

    @Test("Handles \\u unicode escape in string")
    func unicodeEscape4() throws {
        let tokens = try lexer.tokenize("\"\\u0041\\u0042\"")
        #expect(tokens == [.stringLiteral("AB")])
    }

    @Test("Handles \\U unicode escape in string")
    func unicodeEscape8() throws {
        let tokens = try lexer.tokenize("\"\\U00000041\"")
        #expect(tokens == [.stringLiteral("A")])
    }

    @Test("Throws on unknown escape sequence")
    func unknownEscape() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"\\q\"")
        }
    }

    @Test("Throws on unterminated escape at end of string")
    func unterminatedEscape() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"\\")
        }
    }

    @Test("Throws on incomplete unicode escape")
    func incompleteUnicodeEscape() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"\\u00\"")
        }
    }

    @Test("Throws on invalid unicode codepoint")
    func invalidUnicodeCodepoint() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("\"\\UFFFFFFFF\"")
        }
    }

    // MARK: - Prefixed Names

    @Test("Tokenizes prefixed name")
    func prefixedName() throws {
        let tokens = try lexer.tokenize("ex:Person")
        #expect(tokens == [.prefixedName("ex", "Person")])
    }

    @Test("Tokenizes prefixed name with empty local")
    func prefixedNameEmptyLocal() throws {
        let tokens = try lexer.tokenize("ex:")
        #expect(tokens == [.prefixedName("ex", "")])
    }

    @Test("Tokenizes default prefix (bare colon)")
    func defaultPrefix() throws {
        let tokens = try lexer.tokenize(":localName")
        #expect(tokens == [.prefixedName("", "localName")])
    }

    @Test("Tokenizes prefixed name with hyphen")
    func prefixedNameWithHyphen() throws {
        let tokens = try lexer.tokenize("ex:my-class")
        #expect(tokens == [.prefixedName("ex", "my-class")])
    }

    @Test("Tokenizes prefixed name with dot not at end")
    func prefixedNameWithDot() throws {
        let tokens = try lexer.tokenize("ex:a.b")
        #expect(tokens == [.prefixedName("ex", "a.b")])
    }

    @Test("Trailing dot is not part of local name")
    func prefixedNameTrailingDot() throws {
        let tokens = try lexer.tokenize("ex:Person.")
        #expect(tokens == [.prefixedName("ex", "Person"), .dot])
    }

    // MARK: - Blank Nodes

    @Test("Tokenizes blank node label")
    func blankNodeLabel() throws {
        let tokens = try lexer.tokenize("_:b0")
        #expect(tokens == [.blankNodeLabel("b0")])
    }

    @Test("Tokenizes blank node with hyphens")
    func blankNodeWithHyphens() throws {
        let tokens = try lexer.tokenize("_:a-b-c")
        #expect(tokens == [.blankNodeLabel("a-b-c")])
    }

    @Test("Blank node label strips trailing dot")
    func blankNodeTrailingDot() throws {
        let tokens = try lexer.tokenize("_:node1.")
        #expect(tokens == [.blankNodeLabel("node1"), .dot])
    }

    @Test("Throws when _ not followed by colon")
    func blankNodeMissingColon() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("_x")
        }
    }

    // MARK: - Numbers

    @Test("Tokenizes integer")
    func integer() throws {
        let tokens = try lexer.tokenize("42")
        #expect(tokens == [.integer("42")])
    }

    @Test("Tokenizes negative integer")
    func negativeInteger() throws {
        let tokens = try lexer.tokenize("-7")
        #expect(tokens == [.integer("-7")])
    }

    @Test("Tokenizes positive integer")
    func positiveInteger() throws {
        let tokens = try lexer.tokenize("+3")
        #expect(tokens == [.integer("+3")])
    }

    @Test("Tokenizes decimal")
    func decimal() throws {
        let tokens = try lexer.tokenize("3.14")
        #expect(tokens == [.decimal("3.14")])
    }

    @Test("Tokenizes decimal starting with dot")
    func decimalStartingWithDot() throws {
        let tokens = try lexer.tokenize(".5")
        #expect(tokens == [.decimal(".5")])
    }

    @Test("Tokenizes negative decimal")
    func negativeDecimal() throws {
        let tokens = try lexer.tokenize("-0.5")
        #expect(tokens == [.decimal("-0.5")])
    }

    @Test("Tokenizes double with exponent")
    func doubleExponent() throws {
        let tokens = try lexer.tokenize("1.0e5")
        #expect(tokens == [.double("1.0e5")])
    }

    @Test("Tokenizes double with negative exponent")
    func doubleNegativeExponent() throws {
        let tokens = try lexer.tokenize("1E-10")
        #expect(tokens == [.double("1E-10")])
    }

    @Test("Tokenizes double with positive exponent")
    func doublePositiveExponent() throws {
        let tokens = try lexer.tokenize("2.5e+3")
        #expect(tokens == [.double("2.5e+3")])
    }

    @Test("Integer followed by dot is integer then dot")
    func integerThenDot() throws {
        let tokens = try lexer.tokenize("42 .")
        #expect(tokens == [.integer("42"), .dot])
    }

    // MARK: - Booleans

    @Test("Tokenizes true")
    func booleanTrue() throws {
        let tokens = try lexer.tokenize("true")
        #expect(tokens == [.booleanTrue])
    }

    @Test("Tokenizes false")
    func booleanFalse() throws {
        let tokens = try lexer.tokenize("false")
        #expect(tokens == [.booleanFalse])
    }

    // MARK: - Keywords

    @Test("Tokenizes 'a' keyword")
    func aKeyword() throws {
        let tokens = try lexer.tokenize("a")
        #expect(tokens == [.a])
    }

    @Test("Distinguishes 'a' keyword from 'a:b' prefix")
    func aVsPrefix() throws {
        let tokens = try lexer.tokenize("a:foo")
        #expect(tokens == [.prefixedName("a", "foo")])
    }

    @Test("'a' followed by space is keyword")
    func aKeywordWithSpace() throws {
        let tokens = try lexer.tokenize("a ex:Class")
        #expect(tokens == [.a, .prefixedName("ex", "Class")])
    }

    @Test("Tokenizes PREFIX keyword")
    func sparqlPrefix() throws {
        let tokens = try lexer.tokenize("PREFIX ex: <http://example.org/>")
        #expect(tokens == [
            .sparqlPrefix,
            .prefixedName("ex", ""),
            .iri("http://example.org/"),
        ])
    }

    @Test("Tokenizes BASE keyword")
    func sparqlBase() throws {
        let tokens = try lexer.tokenize("BASE <http://example.org/>")
        #expect(tokens == [.sparqlBase, .iri("http://example.org/")])
    }

    // MARK: - Directives

    @Test("Tokenizes @prefix directive")
    func prefixDirective() throws {
        let tokens = try lexer.tokenize("@prefix")
        #expect(tokens == [.prefixDirective])
    }

    @Test("Tokenizes @base directive")
    func baseDirective() throws {
        let tokens = try lexer.tokenize("@base")
        #expect(tokens == [.baseDirective])
    }

    @Test("Throws on @ not followed by letter")
    func atSignNoLetter() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("@")
        }
    }

    // MARK: - Language Tags

    @Test("Tokenizes language tag")
    func langTag() throws {
        let tokens = try lexer.tokenize("\"hello\"@en")
        #expect(tokens == [.stringLiteral("hello"), .langTag("en")])
    }

    @Test("Tokenizes language tag with subtag")
    func langTagWithSubtag() throws {
        let tokens = try lexer.tokenize("\"hello\"@en-US")
        #expect(tokens == [.stringLiteral("hello"), .langTag("en-US")])
    }

    @Test("Tokenizes language tag with multiple subtags")
    func langTagMultipleSubtags() throws {
        let tokens = try lexer.tokenize("\"hello\"@zh-Hans-CN")
        #expect(tokens == [.stringLiteral("hello"), .langTag("zh-Hans-CN")])
    }

    // MARK: - Datatype

    @Test("Tokenizes ^^ datatype separator")
    func hatHat() throws {
        let tokens = try lexer.tokenize("\"42\"^^xsd:integer")
        #expect(tokens == [
            .stringLiteral("42"),
            .hatHat,
            .prefixedName("xsd", "integer"),
        ])
    }

    @Test("Throws on single ^")
    func singleHat() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("^")
        }
    }

    // MARK: - Punctuation

    @Test("Tokenizes all punctuation")
    func punctuation() throws {
        let tokens = try lexer.tokenize(". ; , [ ] ( )")
        #expect(tokens == [.dot, .semicolon, .comma, .openBracket, .closeBracket, .openParen, .closeParen])
    }

    // MARK: - Comments

    @Test("Skips full-line comment")
    func fullLineComment() throws {
        let tokens = try lexer.tokenize("# comment\nex:A")
        #expect(tokens == [.prefixedName("ex", "A")])
    }

    @Test("Skips inline comment")
    func inlineComment() throws {
        let tokens = try lexer.tokenize("ex:A # comment\nex:B")
        #expect(tokens == [.prefixedName("ex", "A"), .prefixedName("ex", "B")])
    }

    @Test("Handles comment at end of input without newline")
    func commentAtEOF() throws {
        let tokens = try lexer.tokenize("ex:A # comment")
        #expect(tokens == [.prefixedName("ex", "A")])
    }

    @Test("Handles multiple consecutive comments")
    func multipleComments() throws {
        let tokens = try lexer.tokenize("# c1\n# c2\n# c3\nex:A")
        #expect(tokens == [.prefixedName("ex", "A")])
    }

    // MARK: - Whitespace

    @Test("Handles empty input")
    func emptyInput() throws {
        let tokens = try lexer.tokenize("")
        #expect(tokens.isEmpty)
    }

    @Test("Handles whitespace-only input")
    func whitespaceOnly() throws {
        let tokens = try lexer.tokenize("   \n\t\r\n  ")
        #expect(tokens.isEmpty)
    }

    @Test("Handles comment-only input")
    func commentOnly() throws {
        let tokens = try lexer.tokenize("# just a comment")
        #expect(tokens.isEmpty)
    }

    // MARK: - Unexpected Characters

    @Test("Throws on unexpected character")
    func unexpectedCharacter() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("$")
        }
    }

    @Test("Throws on unexpected identifier")
    func unexpectedIdentifier() {
        #expect(throws: TurtleLexerError.self) {
            try lexer.tokenize("hello")
        }
    }

    // MARK: - Complex Token Sequences

    @Test("Tokenizes complete triple")
    func completeTriple() throws {
        let tokens = try lexer.tokenize("ex:Person a owl:Class .")
        #expect(tokens == [
            .prefixedName("ex", "Person"),
            .a,
            .prefixedName("owl", "Class"),
            .dot,
        ])
    }

    @Test("Tokenizes prefix declaration")
    func prefixDeclaration() throws {
        let tokens = try lexer.tokenize("@prefix ex: <http://example.org/> .")
        #expect(tokens == [
            .prefixDirective,
            .prefixedName("ex", ""),
            .iri("http://example.org/"),
            .dot,
        ])
    }

    @Test("Tokenizes blank node property list")
    func blankNodePropertyList() throws {
        let tokens = try lexer.tokenize("[ a owl:Class ; rdfs:label \"Thing\" ]")
        #expect(tokens == [
            .openBracket,
            .a,
            .prefixedName("owl", "Class"),
            .semicolon,
            .prefixedName("rdfs", "label"),
            .stringLiteral("Thing"),
            .closeBracket,
        ])
    }

    @Test("Tokenizes collection")
    func collection() throws {
        let tokens = try lexer.tokenize("( ex:A ex:B ex:C )")
        #expect(tokens == [
            .openParen,
            .prefixedName("ex", "A"),
            .prefixedName("ex", "B"),
            .prefixedName("ex", "C"),
            .closeParen,
        ])
    }

    @Test("Tokenizes typed literal with full IRI datatype")
    func typedLiteralFullIRI() throws {
        let tokens = try lexer.tokenize("\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>")
        #expect(tokens == [
            .stringLiteral("42"),
            .hatHat,
            .iri("http://www.w3.org/2001/XMLSchema#integer"),
        ])
    }
}
