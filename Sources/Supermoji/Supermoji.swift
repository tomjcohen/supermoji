import ArgumentParser
import Foundation
import SupermojiKit

@main
struct Supermoji: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate animated GIFs from emoji and images"
    )

    @Argument(help: "Emoji characters and/or image file paths to include as frames")
    var inputs: [String]

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 256

    @Option(name: .long, help: "Frame delay in milliseconds")
    var delay: Int = 500

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        let sources = parseInputs(inputs)

        guard !sources.isEmpty else {
            throw ValidationError("No emoji or image inputs provided")
        }

        let frames = try sources.map { try renderFrame($0, size: size) }
        let outputURL = URL(fileURLWithPath: output)
        let effectiveDelay = frames.count == 1 ? 0 : delay

        try writeGIF(frames: frames, delayMs: effectiveDelay, to: outputURL)

        if frames.count == 1 {
            print("Wrote static GIF: \(output) (\(size)x\(size))")
        } else {
            print("Wrote animated GIF: \(output) (\(frames.count) frames, \(size)x\(size), \(delay)ms delay)")
        }
    }
}

/// Parses CLI arguments into frame sources.
/// If an argument is a path to an existing file, it becomes `.image`.
/// Otherwise it's treated as emoji text and split into grapheme clusters.
func parseInputs(_ inputs: [String]) -> [FrameSource] {
    inputs.flatMap { input -> [FrameSource] in
        if FileManager.default.fileExists(atPath: input) {
            return [.image(URL(fileURLWithPath: input))]
        } else {
            return splitEmoji(input).map { .emoji($0) }
        }
    }
}
