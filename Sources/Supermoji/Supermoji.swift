import ArgumentParser
import Foundation
import SupermojiKit

@main
struct Supermoji: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate animated or static GIFs from emoji and images",
        subcommands: [Animate.self, Fade.self, Still.self],
        defaultSubcommand: Animate.self
    )
}

// MARK: - animate (default)

/// The original behaviour: N mixed emoji/image inputs → frame-swap GIF (a single
/// input collapses to a static GIF). Kept byte-compatible; runs by default so
/// `supermoji 😀😃😄` still works without naming a subcommand.
struct Animate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Cycle through emoji and/or images as GIF frames (default)"
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

// MARK: - fade

/// Cross-fade between two emoji and back, as a seamless looping GIF.
struct Fade: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Cross-fade between two emoji and back, as a looping GIF"
    )

    @Argument(help: "Exactly two emoji to fade between")
    var inputs: [String]

    @Option(name: .long, help: "Easing curve: linear, ease-in, ease-out, ease-in-out")
    var curve: EasingCurve = .easeInOut

    @Option(name: .long, help: "Frames per second")
    var fps: Int = 20

    @Option(name: .long, help: "One-way fade duration in seconds")
    var duration: Double = 0.6

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 128

    @Option(name: .long, help: "Internal supersampling factor for smoother output")
    var supersample: Int = 3

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        try requireMacOS()
        let emoji = try graphemes(inputs, count: 2)
        let frames = try makeFadeFrames(
            from: emoji[0], to: emoji[1], curve: curve, fps: fps, duration: duration,
            size: size, supersample: supersample
        )
        let url = URL(fileURLWithPath: output)
        let delayMs = max(1, Int((1000.0 / Double(fps)).rounded()))
        try writeGIF(frames: frames, delayMs: delayMs, to: url)
        print("Wrote fade GIF: \(output) (\(frames.count) frames, \(size)x\(size), \(emoji[0])→\(emoji[1]), \(curve.rawValue))")
        warnIfOversized(url)
    }
}

// MARK: - still

/// Render a single emoji as a static GIF using the same renderer as `fade`,
/// so stills and fades render at a uniform size as Slack custom emoji.
struct Still: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Render a single emoji as a static GIF"
    )

    @Argument(help: "Exactly one emoji")
    var inputs: [String]

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 128

    @Option(name: .long, help: "Internal supersampling factor for smoother output")
    var supersample: Int = 3

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        try requireMacOS()
        let emoji = try graphemes(inputs, count: 1)
        let frame = try renderEmojiFrame(emoji[0], size: size, supersample: supersample)
        let url = URL(fileURLWithPath: output)
        try writeGIF(frames: [frame], delayMs: 0, to: url)
        print("Wrote still GIF: \(output) (\(size)x\(size), \(emoji[0]))")
        warnIfOversized(url)
    }
}

// MARK: - Helpers

extension EasingCurve: ExpressibleByArgument {}

/// Splits all inputs into grapheme clusters and requires an exact count.
func graphemes(_ inputs: [String], count: Int) throws -> [String] {
    let parsed = inputs.flatMap { splitEmoji($0) }
    guard parsed.count == count else {
        throw ValidationError("Expected exactly \(count) emoji, got \(parsed.count): \(parsed.joined(separator: " "))")
    }
    return parsed
}

/// Errors before doing any AppKit work if somehow run off macOS.
func requireMacOS() throws {
    #if !os(macOS)
    throw ValidationError("supermoji requires macOS — it renders Apple Color Emoji.")
    #endif
}

/// Warns (non-fatal) if the GIF exceeds Slack's 128 KB custom-emoji limit.
func warnIfOversized(_ url: URL) {
    let slackLimit = 128 * 1024
    guard let bytes = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
          bytes > slackLimit else { return }
    let message = "Warning: \(bytes / 1024) KB exceeds Slack's 128 KB custom-emoji limit. Try lowering --fps, --duration, or --size.\n"
    FileHandle.standardError.write(Data(message.utf8))
}

/// Parses CLI arguments into frame sources for `animate`.
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
