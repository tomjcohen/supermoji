@preconcurrency import AppKit
import CoreGraphics

enum RenderError: Error, CustomStringConvertible {
    case failedToCreateContext
    case failedToCreateImage

    var description: String {
        switch self {
        case .failedToCreateContext: "Failed to create graphics context"
        case .failedToCreateImage: "Failed to create image from context"
        }
    }
}

/// Renders a single emoji character into a CGImage at the given pixel size.
func renderEmoji(_ emoji: String, size: Int) throws -> CGImage {
    let cgSize = CGFloat(size)

    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw RenderError.failedToCreateContext
    }

    let fontSize = cgSize * 0.85
    let font = NSFont.systemFont(ofSize: fontSize)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
    ]
    let attrString = NSAttributedString(string: emoji, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attrString)

    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let xOffset = (cgSize - bounds.width) / 2 - bounds.origin.x
    let yOffset = (cgSize - bounds.height) / 2 - bounds.origin.y

    context.textPosition = CGPoint(x: xOffset, y: yOffset)
    CTLineDraw(line, context)

    guard let image = context.makeImage() else {
        throw RenderError.failedToCreateImage
    }

    return image
}
