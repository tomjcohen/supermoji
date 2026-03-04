import ArgumentParser

@main
struct Supermoji: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate animated GIFs from emoji"
    )

    @Argument(help: "Emoji characters to render")
    var emoji: String

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 256

    @Option(name: .long, help: "Frame delay in milliseconds")
    var delay: Int = 500

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        print("supermoji: \(emoji) size=\(size) delay=\(delay) output=\(output)")
    }
}
