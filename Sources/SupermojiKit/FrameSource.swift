import Foundation
import CoreGraphics

public enum FrameSource: Sendable {
    case emoji(String)
    case image(URL)
}

/// Renders a single frame source to a CGImage at the given pixel size.
public func renderFrame(_ source: FrameSource, size: Int) throws -> CGImage {
    switch source {
    case .emoji(let character):
        return try renderEmoji(character, size: size)
    case .image(let url):
        return try loadImage(from: url, size: size)
    }
}
