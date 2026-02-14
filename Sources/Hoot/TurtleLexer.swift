/// Error during Turtle lexical analysis.
public struct TurtleLexerError: Error, Sendable {
    public let message: String
    public let offset: Int

    public init(_ message: String, at offset: Int) {
        self.message = message
        self.offset = offset
    }
}

/// Tokenizes Turtle format text into a sequence of tokens.
public struct TurtleLexer: Sendable {

    public init() {}

    /// Tokenize the input string into Turtle tokens.
    public func tokenize(_ input: String) throws -> [TurtleToken] {
        var scanner = Scanner(input)
        var tokens: [TurtleToken] = []

        while !scanner.isAtEnd {
            scanner.skipWhitespaceAndComments()
            guard !scanner.isAtEnd else { break }

            let c = scanner.peek()

            switch c {
            case "<":
                tokens.append(try scanner.scanIRI())
            case "\"":
                tokens.append(try scanner.scanStringLiteral())
            case "'":
                tokens.append(try scanner.scanSingleQuoteStringLiteral())
            case "@":
                tokens.append(try scanner.scanAtSign())
            case "_":
                tokens.append(try scanner.scanBlankNode())
            case ".":
                if scanner.isDecimalStartingWithDot() {
                    tokens.append(try scanner.scanNumber())
                } else {
                    scanner.advance()
                    tokens.append(.dot)
                }
            case ";":
                scanner.advance()
                tokens.append(.semicolon)
            case ",":
                scanner.advance()
                tokens.append(.comma)
            case "[":
                scanner.advance()
                tokens.append(.openBracket)
            case "]":
                scanner.advance()
                tokens.append(.closeBracket)
            case "(":
                scanner.advance()
                tokens.append(.openParen)
            case ")":
                scanner.advance()
                tokens.append(.closeParen)
            case "^":
                tokens.append(try scanner.scanHatHat())
            default:
                if c == "+" || c == "-" || c.isNumber {
                    tokens.append(try scanner.scanNumber())
                } else if c.isLetter || c == ":" {
                    tokens.append(try scanner.scanNameOrKeyword())
                } else {
                    throw TurtleLexerError("Unexpected character: '\(c)'", at: scanner.position)
                }
            }
        }

        return tokens
    }
}

// MARK: - Scanner

private struct Scanner {
    let chars: [Character]
    var pos: Int

    init(_ input: String) {
        self.chars = Array(input)
        self.pos = 0
    }

    var isAtEnd: Bool { pos >= chars.count }
    var position: Int { pos }

    func peek() -> Character {
        chars[pos]
    }

    func peek(offset: Int) -> Character? {
        let idx = pos + offset
        return idx < chars.count ? chars[idx] : nil
    }

    mutating func advance() {
        pos += 1
    }

    mutating func advance(by n: Int) {
        pos += n
    }

    // MARK: - Whitespace & Comments

    mutating func skipWhitespaceAndComments() {
        while !isAtEnd {
            let c = peek()
            if c.isWhitespace {
                advance()
            } else if c == "#" {
                skipToEndOfLine()
            } else {
                break
            }
        }
    }

    private mutating func skipToEndOfLine() {
        while !isAtEnd {
            let c = peek()
            advance()
            if c == "\n" || c == "\r" { break }
        }
    }

    // MARK: - IRI

    mutating func scanIRI() throws -> TurtleToken {
        let start = pos
        advance() // skip '<'
        var content = ""
        while !isAtEnd {
            let c = peek()
            if c == ">" {
                advance()
                return .iri(content)
            }
            if c == "\\" {
                advance()
                guard !isAtEnd else {
                    throw TurtleLexerError("Unterminated IRI escape", at: start)
                }
                let escaped = peek()
                advance()
                if escaped == "u" {
                    content.append(try scanUnicodeEscape(length: 4, start: start))
                } else if escaped == "U" {
                    content.append(try scanUnicodeEscape(length: 8, start: start))
                } else {
                    content.append(escaped)
                }
            } else {
                content.append(c)
                advance()
            }
        }
        throw TurtleLexerError("Unterminated IRI", at: start)
    }

    // MARK: - String Literals

    mutating func scanStringLiteral() throws -> TurtleToken {
        let start = pos
        advance() // skip first '"'

        // Check for long string """..."""
        if !isAtEnd && peek() == "\"" {
            if peek(offset: 1) == "\"" {
                advance() // skip second '"'
                advance() // skip third '"'
                return try scanLongString(start: start, quote: "\"")
            } else {
                // Empty string ""
                advance() // skip second '"'
                return .stringLiteral("")
            }
        }

        return try scanShortString(start: start, quote: "\"")
    }

    mutating func scanSingleQuoteStringLiteral() throws -> TurtleToken {
        let start = pos
        advance() // skip first '

        // Check for long string '''...'''
        if !isAtEnd && peek() == "'" {
            if peek(offset: 1) == "'" {
                advance()
                advance()
                return try scanLongString(start: start, quote: "'")
            } else {
                advance()
                return .stringLiteral("")
            }
        }

        return try scanShortString(start: start, quote: "'")
    }

    private mutating func scanShortString(start: Int, quote: Character) throws -> TurtleToken {
        var content = ""
        while !isAtEnd {
            let c = peek()
            if c == quote {
                advance()
                return .stringLiteral(content)
            }
            if c == "\n" || c == "\r" {
                throw TurtleLexerError("Newline in short string", at: pos)
            }
            if c == "\\" {
                advance()
                content.append(try scanStringEscape(start: start))
            } else {
                content.append(c)
                advance()
            }
        }
        throw TurtleLexerError("Unterminated string literal", at: start)
    }

    private mutating func scanLongString(start: Int, quote: Character) throws -> TurtleToken {
        var content = ""
        while !isAtEnd {
            let c = peek()
            if c == quote && peek(offset: 1) == quote && peek(offset: 2) == quote {
                advance(by: 3)
                return .stringLiteral(content)
            }
            if c == "\\" {
                advance()
                content.append(try scanStringEscape(start: start))
            } else {
                content.append(c)
                advance()
            }
        }
        throw TurtleLexerError("Unterminated long string", at: start)
    }

    private mutating func scanStringEscape(start: Int) throws -> Character {
        guard !isAtEnd else {
            throw TurtleLexerError("Unterminated escape sequence", at: start)
        }
        let c = peek()
        advance()
        switch c {
        case "\\": return "\\"
        case "\"": return "\""
        case "'": return "'"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "u": return try scanUnicodeEscape(length: 4, start: start)
        case "U": return try scanUnicodeEscape(length: 8, start: start)
        default:
            throw TurtleLexerError("Unknown escape sequence: \\'\(c)'", at: start)
        }
    }

    private mutating func scanUnicodeEscape(length: Int, start: Int) throws -> Character {
        var hex = ""
        for _ in 0..<length {
            guard !isAtEnd else {
                throw TurtleLexerError("Incomplete unicode escape", at: start)
            }
            hex.append(peek())
            advance()
        }
        guard let codePoint = UInt32(hex, radix: 16),
              let scalar = Unicode.Scalar(codePoint) else {
            throw TurtleLexerError("Invalid unicode escape: \\u\(hex)", at: start)
        }
        return Character(scalar)
    }

    // MARK: - @ (prefix/base/langTag)

    mutating func scanAtSign() throws -> TurtleToken {
        let start = pos
        advance() // skip '@'

        guard !isAtEnd && peek().isLetter else {
            throw TurtleLexerError("Expected letter after @", at: start)
        }

        let word = scanWord()

        if word == "prefix" {
            return .prefixDirective
        } else if word == "base" {
            return .baseDirective
        } else {
            // Language tag: may contain '-' and more letters/digits
            var tag = word
            while !isAtEnd && peek() == "-" {
                tag.append(peek())
                advance()
                tag.append(scanWord())
            }
            return .langTag(tag)
        }
    }

    // MARK: - Blank Node

    mutating func scanBlankNode() throws -> TurtleToken {
        let start = pos
        advance() // skip '_'
        guard !isAtEnd && peek() == ":" else {
            throw TurtleLexerError("Expected ':' after '_'", at: start)
        }
        advance() // skip ':'

        var label = ""
        while !isAtEnd {
            let c = peek()
            if c.isLetter || c.isNumber || c == "_" || c == "-" || c == "." {
                label.append(c)
                advance()
            } else {
                break
            }
        }
        // Blank node label cannot end with '.'
        while label.hasSuffix(".") {
            label.removeLast()
            pos -= 1
        }
        return .blankNodeLabel(label)
    }

    // MARK: - ^^

    mutating func scanHatHat() throws -> TurtleToken {
        let start = pos
        advance() // skip first '^'
        guard !isAtEnd && peek() == "^" else {
            throw TurtleLexerError("Expected '^^'", at: start)
        }
        advance() // skip second '^'
        return .hatHat
    }

    // MARK: - Numbers

    func isDecimalStartingWithDot() -> Bool {
        guard let next = peek(offset: 1) else { return false }
        return next.isNumber
    }

    mutating func scanNumber() throws -> TurtleToken {
        var num = ""
        var hasDecimalPoint = false
        var hasExponent = false

        // Sign
        if !isAtEnd && (peek() == "+" || peek() == "-") {
            num.append(peek())
            advance()
        }

        // Integer part (may be empty if starting with '.')
        while !isAtEnd && peek().isNumber {
            num.append(peek())
            advance()
        }

        // Decimal point
        if !isAtEnd && peek() == "." {
            // Only consume if followed by a digit
            if let next = peek(offset: 1), next.isNumber {
                hasDecimalPoint = true
                num.append(".")
                advance()
                while !isAtEnd && peek().isNumber {
                    num.append(peek())
                    advance()
                }
            }
        }

        // Exponent
        if !isAtEnd && (peek() == "e" || peek() == "E") {
            hasExponent = true
            num.append(peek())
            advance()
            if !isAtEnd && (peek() == "+" || peek() == "-") {
                num.append(peek())
                advance()
            }
            while !isAtEnd && peek().isNumber {
                num.append(peek())
                advance()
            }
        }

        if hasExponent {
            return .double(num)
        } else if hasDecimalPoint {
            return .decimal(num)
        } else {
            return .integer(num)
        }
    }

    // MARK: - Name or Keyword

    mutating func scanNameOrKeyword() throws -> TurtleToken {
        // Handle bare colon (default prefix)
        if peek() == ":" {
            advance()
            let local = scanLocalName()
            return .prefixedName("", local)
        }

        let word = scanWord()

        // Check keywords
        switch word {
        case "true": return .booleanTrue
        case "false": return .booleanFalse
        case "a":
            // 'a' is keyword only if not followed by name character or ':'
            if isAtEnd || (!peek().isLetter && !peek().isNumber && peek() != "_" && peek() != ":" && peek() != "-" && peek() != ".") {
                return .a
            }
            // Otherwise, it's the start of a prefixed name like "a:foo" or a longer word "abc"
            // But we already consumed "a", so if next is ':', it's prefix "a"
            if peek() == ":" {
                advance()
                let local = scanLocalName()
                return .prefixedName(word, local)
            }
            // Continue reading as a longer word
            var extended = word
            extended.append(contentsOf: scanWordContinuation())
            if !isAtEnd && peek() == ":" {
                advance()
                let local = scanLocalName()
                return .prefixedName(extended, local)
            }
            // Standalone word that starts with 'a' but isn't a prefix - treat as error or prefix with no colon
            throw TurtleLexerError("Unexpected identifier: '\(extended)'", at: pos)
        case "PREFIX":
            return .sparqlPrefix
        case "BASE":
            return .sparqlBase
        default:
            break
        }

        // Should be a prefixed name
        if !isAtEnd && peek() == ":" {
            advance()
            let local = scanLocalName()
            return .prefixedName(word, local)
        }

        throw TurtleLexerError("Unexpected identifier: '\(word)'", at: pos)
    }

    private mutating func scanWord() -> String {
        var word = ""
        while !isAtEnd {
            let c = peek()
            if c.isLetter || c.isNumber || c == "_" {
                word.append(c)
                advance()
            } else {
                break
            }
        }
        return word
    }

    private mutating func scanWordContinuation() -> String {
        var word = ""
        while !isAtEnd {
            let c = peek()
            if c.isLetter || c.isNumber || c == "_" || c == "-" {
                word.append(c)
                advance()
            } else {
                break
            }
        }
        return word
    }

    private mutating func scanLocalName() -> String {
        var local = ""
        while !isAtEnd {
            let c = peek()
            if c.isLetter || c.isNumber || c == "_" || c == "-" || c == "." {
                local.append(c)
                advance()
            } else {
                break
            }
        }
        // Local name cannot end with '.'
        while local.hasSuffix(".") {
            local.removeLast()
            pos -= 1
        }
        return local
    }
}
