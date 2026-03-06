import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import SupermojiKit

@Test func renderFrameWithEmoji() throws {
    let result = try renderFrame(.emoji("😀"), size: 64)
    #expect(result.width == 64)
    #expect(result.height == 64)
}

@Test func renderFrameWithImage() throws {
    // Create a temp PNG to load
    let context = CGContext(
        data: nil, width: 50, height: 50,
        bitsPerComponent: 8, bytesPerRow: 50 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
    let img = context.makeImage()!

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-framesource.png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try renderFrame(.image(url), size: 64)
    #expect(result.width == 64)
    #expect(result.height == 64)
}
