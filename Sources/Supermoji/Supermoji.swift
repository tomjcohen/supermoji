import ArgumentParser
import Foundation
import SupermojiKit

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
        let characters = splitEmoji(emoji)

        guard !characters.isEmpty else {
            throw ValidationError("No emoji characters provided")
        }

        let frames = try characters.map { try renderEmoji($0, size: size) }
        let outputURL = URL(fileURLWithPath: output)
        let effectiveDelay = characters.count == 1 ? 0 : delay

        try writeGIF(frames: frames, delayMs: effectiveDelay, to: outputURL)

        if characters.count == 1 {
            print("Wrote static GIF: \(output) (\(size)x\(size))")
        } else {
            print("Wrote animated GIF: \(output) (\(characters.count) frames, \(size)x\(size), \(delay)ms delay)")
        }
    }
}
