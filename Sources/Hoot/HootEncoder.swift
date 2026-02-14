/// Encoding mode for HOOT output.
public enum HootEncodingMode: Sendable {
    /// Lossless: preserves all information for round-trip with Turtle.
    case lossless

    /// Compact: omits derivable information for minimum token count.
    case compact
}

/// Encodes a `HootDocument` into HOOT text format.
public struct HootEncoder: Sendable {

    public var mode: HootEncodingMode

    public init(mode: HootEncodingMode = .lossless) {
        self.mode = mode
    }

    /// Encode a document to HOOT format string.
    public func encode(_ document: HootDocument) -> String {
        // Compact mode: convert single custom prefix to default (empty) prefix
        var doc = document
        if mode == .compact {
            let customPrefixes = doc.prefixes.filter { !isStandardPrefix($0.name) && !$0.name.isEmpty }
            if customPrefixes.count == 1 {
                doc = doc.usingDefaultPrefix(customPrefixes[0].name)
            }
        }

        var lines: [String] = []

        // 1. Prefix declarations
        for prefix in doc.prefixes {
            if mode == .compact && isStandardPrefix(prefix.name) {
                continue
            }
            lines.append("@\(prefix.name) \(compactIRI(prefix.iri))")
        }

        // 2. Sections
        for section in doc.sections {
            if !lines.isEmpty { lines.append("") }
            switch section {
            case .classHierarchy(let hierarchy):
                encodeClassHierarchy(hierarchy, into: &lines)
            case .tabular(let tabular):
                encodeTabular(tabular, into: &lines)
            case .disjoint(let disjoint):
                encodeDisjoint(disjoint, into: &lines)
            case .subjectBlock(let block):
                encodeSubjectBlock(block, into: &lines)
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Class Hierarchy

    private func encodeClassHierarchy(_ hierarchy: HootClassHierarchy, into lines: inout [String]) {
        lines.append("class \(hierarchy.root)")
        for cls in hierarchy.classes {
            encodeClass(cls, depth: 1, into: &lines)
        }
    }

    private func encodeClass(_ cls: HootClass, depth: Int, into lines: inout [String]) {
        let indent = String(repeating: " ", count: depth)
        var line = "\(indent)\(cls.iri)"
        if let label = cls.label {
            // Compact mode: omit label when it matches the IRI local name
            if mode != .compact || label != localName(of: cls.iri) {
                line += " \"\(escapeString(label))\""
            }
        }
        lines.append(line)
        for child in cls.children {
            encodeClass(child, depth: depth + 1, into: &lines)
        }
    }

    private func localName(of iri: String) -> String {
        if let colonIndex = iri.lastIndex(of: ":") {
            return String(iri[iri.index(after: colonIndex)...])
        }
        return iri
    }

    // MARK: - Tabular Section

    private func sectionSymbol(_ name: String) -> String {
        switch name {
        case "ObjectProperty": return "->"
        case "DataProperty": return "=>"
        case "AnnotationProperty": return "@>"
        default: return name
        }
    }

    private func encodeTabular(_ section: HootTabularSection, into lines: inout [String]) {
        let symbol = sectionSymbol(section.name)
        let header = "\(symbol){\(section.fields.joined(separator: ","))}:"
        lines.append(header)
        for row in section.rows {
            let trimmed = trimTrailingEmpty(row)
            let values = trimmed.map { quoteIfNeeded($0) }
            lines.append(" \(values.joined(separator: ","))")
        }
    }

    // MARK: - Disjoint Section

    private func encodeDisjoint(_ section: HootDisjointSection, into lines: inout [String]) {
        let groups = section.groups.map { group in
            "(\(group.joined(separator: " ")))"
        }
        lines.append("! \(groups.joined(separator: ","))")
    }

    // MARK: - Subject Block

    private func encodeSubjectBlock(_ block: HootSubjectBlock, into lines: inout [String]) {
        lines.append("\(block.subject):")
        for property in block.properties {
            encodeProperty(property, depth: 1, into: &lines)
        }
    }

    private func encodeProperty(_ property: HootProperty, depth: Int, into lines: inout [String]) {
        let indent = String(repeating: " ", count: depth)

        if property.objects.count == 1, case .inlineBlankNode(let props) = property.objects[0] {
            lines.append("\(indent)\(property.predicate) [")
            for p in props {
                encodeProperty(p, depth: depth + 1, into: &lines)
            }
            lines.append("\(indent)]")
        } else if property.objects.count == 1, case .collection(let items) = property.objects[0] {
            let rendered = items.map { renderValue($0, depth: depth) }.joined(separator: " ")
            lines.append("\(indent)\(property.predicate) (\(rendered))")
        } else {
            let rendered = property.objects.map { renderValue($0, depth: depth) }.joined(separator: ",")
            lines.append("\(indent)\(property.predicate) \(rendered)")
        }
    }

    private func renderValue(_ value: HootValue, depth: Int) -> String {
        switch value {
        case .iri(let iri):
            return iri
        case .literal(let text, let datatype, let language):
            var result = "\"\(escapeString(text))\""
            if let lang = language {
                result += "@\(lang)"
            } else if let dt = datatype {
                result += "^^\(dt)"
            }
            return result
        case .number(let num):
            return num
        case .boolean(let val):
            return val ? "true" : "false"
        case .blankNode(let label):
            return "_:\(label)"
        case .inlineBlankNode(let props):
            var subLines: [String] = ["["]
            for p in props {
                encodeProperty(p, depth: depth + 1, into: &subLines)
            }
            subLines.append(String(repeating: " ", count: depth) + "]")
            return subLines.joined(separator: "\n")
        case .collection(let items):
            let rendered = items.map { renderValue($0, depth: depth) }.joined(separator: " ")
            return "(\(rendered))"
        }
    }

    // MARK: - Helpers

    private func trimTrailingEmpty(_ row: [String]) -> [String] {
        var result = row
        while result.last == "" {
            result.removeLast()
        }
        return result
    }

    private func quoteIfNeeded(_ value: String) -> String {
        if value.isEmpty { return "" }

        let needsQuoting =
            value.contains(",") ||
            value.contains("\"") ||
            value.contains("\\") ||
            value.contains("(") ||
            value.contains(")") ||
            value.contains("[") ||
            value.contains("]") ||
            value.contains("{") ||
            value.contains("}") ||
            value.hasPrefix(" ") ||
            value.hasSuffix(" ") ||
            value == "true" ||
            value == "false" ||
            value == "null" ||
            value == "a" ||
            value == "class"

        guard needsQuoting else { return value }
        return "\"\(escapeString(value))\""
    }

    private func escapeString(_ value: String) -> String {
        var escaped = ""
        for char in value {
            switch char {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\t": escaped += "\\t"
            default: escaped.append(char)
            }
        }
        return escaped
    }

    private func compactIRI(_ iri: String) -> String {
        var result = iri
        // Strip http://
        if result.hasPrefix("http://") {
            result = String(result.dropFirst("http://".count))
        }
        // Strip trailing / or #
        if result.hasSuffix("/") || result.hasSuffix("#") {
            result = String(result.dropLast())
        }
        return "//\(result)"
    }

    private func isStandardPrefix(_ name: String) -> Bool {
        ["owl", "rdfs", "rdf", "xsd"].contains(name)
    }
}
