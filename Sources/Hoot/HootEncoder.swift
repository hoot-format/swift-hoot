/// Encodes a `HootDocument` into HOOT text format.
public struct HootEncoder: Sendable {

    public init() {}

    /// Encode a document to HOOT format string.
    public func encode(_ document: HootDocument) -> String {
        var lines: [String] = []

        // 1. Prefix declarations
        for prefix in document.prefixes {
            lines.append("@prefix \(prefix.short): <\(prefix.iri)>")
        }

        // 2. Class hierarchy
        if !document.classes.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("owl:Thing")
            for cls in document.classes {
                encodeClass(cls, depth: 1, into: &lines)
            }
        }

        // 3. Sections
        for section in document.sections {
            lines.append("")
            switch section {
            case .tabular(let tabular):
                encodeTabular(tabular, into: &lines)
            case .inline(let inline):
                encodeInline(inline, into: &lines)
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func encodeClass(_ cls: HootClass, depth: Int, into lines: inout [String]) {
        let indent = String(repeating: " ", count: depth)
        lines.append("\(indent)\(cls.name)")
        for child in cls.children {
            encodeClass(child, depth: depth + 1, into: &lines)
        }
    }

    private func encodeTabular(_ section: HootTabularSection, into lines: inout [String]) {
        let header = "\(section.name){\(section.fields.joined(separator: ","))}:"
        lines.append(header)
        for row in section.rows {
            let trimmed = trimTrailingEmpty(row)
            let values = trimmed.map { quoteIfNeeded($0) }
            lines.append(" \(values.joined(separator: ","))")
        }
    }

    private func encodeInline(_ section: HootInlineSection, into lines: inout [String]) {
        let groups = section.groups.map { group in
            "{\(group.map { quoteIfNeeded($0) }.joined(separator: ","))}"
        }
        lines.append("\(section.name): \(groups.joined(separator: ","))")
    }

    /// Remove trailing empty strings from a row.
    private func trimTrailingEmpty(_ row: [String]) -> [String] {
        var result = row
        while result.last == "" {
            result.removeLast()
        }
        return result
    }

    /// Quote a value if it contains characters that require quoting.
    private func quoteIfNeeded(_ value: String) -> String {
        if value.isEmpty { return "" }

        let needsQuoting =
            value.contains(",") ||
            value.contains(":") ||
            value.contains("\"") ||
            value.contains("\\") ||
            value.contains("{") ||
            value.contains("}") ||
            value.contains("[") ||
            value.contains("]") ||
            value.hasPrefix(" ") ||
            value.hasSuffix(" ") ||
            value == "true" ||
            value == "false" ||
            value == "null"

        guard needsQuoting else { return value }

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

        return "\"\(escaped)\""
    }
}
