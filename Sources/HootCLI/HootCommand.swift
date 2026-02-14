import ArgumentParser
import Hoot
import Foundation

@main
struct HootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hoot",
        abstract: "Convert Turtle RDF files to HOOT format."
    )

    @Argument(help: "Input Turtle file (.ttl)")
    var input: String

    @Flag(name: .long, help: "Use compact encoding mode")
    var compact: Bool = false

    @Option(name: .shortAndLong, help: "Output file (default: stdout)")
    var output: String?

    func run() throws {
        let inputURL = URL(fileURLWithPath: input)
        let turtleText = try String(contentsOf: inputURL, encoding: .utf8)

        let parser = TurtleParser()
        let turtleDoc = try parser.parse(turtleText)

        let compiler = HootCompiler()
        let hootDoc = compiler.compile(turtleDoc)

        let encoder = HootEncoder(mode: compact ? .compact : .lossless)
        let hootText = encoder.encode(hootDoc)

        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: outputPath)
            try hootText.write(to: outputURL, atomically: true, encoding: .utf8)
        } else {
            print(hootText, terminator: "")
        }
    }
}
