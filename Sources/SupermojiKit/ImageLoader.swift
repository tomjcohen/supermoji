import Foundation
import CoreGraphics
import ImageIO

public enum ImageLoadError: Error, CustomStringConvertible {
    case failedToLoadImage
    case failedToCreateThumbnail

    public var description: String {
        switch self {
        case .failedToLoadImage: "Failed to load image from file"
        case .failedToCreateThumbnail: "Failed to create scaled image"
        }
    }
}

/// Loads an image from a file URL and scales it to fit within a `size x size` square.
/// The image is aspect-fit and centred on a transparent background.
public func loadImage(from url: URL, size: Int) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw ImageLoadError.failedToLoadImage
    }

    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: size,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ]

    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw ImageLoadError.failedToCreateThumbnail
    }

    // Place aspect-fit image centred on a size x size transparent canvas
    guard let context = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ImageLoadError.failedToCreateThumbnail
    }

    let thumbW = CGFloat(thumbnail.width)
    let thumbH = CGFloat(thumbnail.height)
    let canvasSize = CGFloat(size)
    let scale = min(canvasSize / thumbW, canvasSize / thumbH)
    let drawW = thumbW * scale
    let drawH = thumbH * scale
    let x = (canvasSize - drawW) / 2
    let y = (canvasSize - drawH) / 2

    context.draw(thumbnail, in: CGRect(x: x, y: y, width: drawW, height: drawH))

    guard let result = context.makeImage() else {
        throw ImageLoadError.failedToCreateThumbnail
    }
    return result
}
