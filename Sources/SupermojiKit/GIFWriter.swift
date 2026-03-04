import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum GIFError: Error, CustomStringConvertible {
    case failedToCreateDestination
    case failedToFinalize

    public var description: String {
        switch self {
        case .failedToCreateDestination: "Failed to create GIF destination"
        case .failedToFinalize: "Failed to finalize GIF file"
        }
    }
}

/// Writes an array of CGImages as an animated (or static) GIF.
public func writeGIF(frames: [CGImage], delayMs: Int, to url: URL) throws {
    let frameCount = frames.count
    let isAnimated = frameCount > 1

    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.gif.identifier as CFString,
        frameCount,
        nil
    ) else {
        throw GIFError.failedToCreateDestination
    }

    if isAnimated {
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0, // loop forever
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
    }

    let delaySeconds = Double(delayMs) / 1000.0

    for frame in frames {
        var frameProperties: [String: Any] = [:]
        if isAnimated {
            frameProperties[kCGImagePropertyGIFDictionary as String] = [
                kCGImagePropertyGIFDelayTime as String: delaySeconds,
            ]
        }
        CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
    }

    guard CGImageDestinationFinalize(destination) else {
        throw GIFError.failedToFinalize
    }
}
