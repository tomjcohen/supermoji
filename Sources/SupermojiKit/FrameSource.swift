import Foundation
import CoreGraphics

public struct FrameSource: Sendable, Identifiable {
    public let id: UUID
    public let kind: Kind

    public enum Kind: Sendable {
        case emoji(String)
        case image(URL)
    }

    public init(_ kind: Kind) {
        self.id = UUID()
        self.kind = kind
    }

    public static func emoji(_ char: String) -> FrameSource {
        FrameSource(.emoji(char))
    }

    public static func image(_ url: URL) -> FrameSource {
        FrameSource(.image(url))
    }
}

/// Renders a single frame source to a CGImage at the given pixel size.
public func renderFrame(_ source: FrameSource, size: Int) throws -> CGImage {
    switch source.kind {
    case .emoji(let character):
        return try renderEmoji(character, size: size)
    case .image(let url):
        return try loadImage(from: url, size: size)
    }
}
