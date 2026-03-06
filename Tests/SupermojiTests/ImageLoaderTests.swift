import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import SupermojiKit

/// Helper: creates a CGImage of the given dimensions filled with solid red.
private func makeTestImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// Helper: writes a CGImage as PNG to a temporary file and returns the URL.
private func writeTempPNG(_ image: CGImage, name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw ImageLoadError.failedToLoadImage
    }
    return url
}

@Test func loadsImageAtRequestedSize() throws {
    let source = makeTestImage(width: 100, height: 100)
    let url = try writeTempPNG(source, name: "test-square.png")
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try loadImage(from: url, size: 64)
    #expect(result.width == 64)
    #expect(result.height == 64)
}

@Test func loadsRectangularImageAspectFit() throws {
    let source = makeTestImage(width: 200, height: 100)
    let url = try writeTempPNG(source, name: "test-wide.png")
    defer { try? FileManager.default.removeItem(at: url) }

    // Should fit within 64x64, aspect-fit means the image is centred
    let result = try loadImage(from: url, size: 64)
    #expect(result.width == 64)
    #expect(result.height == 64)
}

@Test func loadImageThrowsForInvalidPath() throws {
    let bogusURL = URL(fileURLWithPath: "/tmp/does-not-exist-12345.png")
    #expect(throws: ImageLoadError.self) {
        try loadImage(from: bogusURL, size: 64)
    }
}
