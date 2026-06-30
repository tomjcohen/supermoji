import Testing
import CoreGraphics
@testable import SupermojiKit

@Test func renderEmojiFrameProducesRequestedSize() throws {
    let image = try renderEmojiFrame("🔵", size: 128)
    #expect(image.width == 128)
    #expect(image.height == 128)
}

@Test func renderEmojiFrameIsRGBA8() throws {
    let image = try renderEmojiFrame("🔵", size: 64)
    guard let data = image.dataProvider?.data else {
        Issue.record("No image data")
        return
    }
    #expect(CFDataGetLength(data) == 64 * 64 * 4)
}

@Test func renderEmojiFrameActuallyDrawsTheGlyph() throws {
    // A rendered circle emoji must have some non-transparent pixels.
    let image = try renderEmojiFrame("🔵", size: 64)
    var buf = [UInt8](repeating: 0, count: 64 * 64 * 4)
    let ctx = CGContext(
        data: &buf, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 64 * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
    let hasOpaquePixel = stride(from: 3, to: buf.count, by: 4).contains { buf[$0] > 0 }
    #expect(hasOpaquePixel)
}

@Test func renderEmojiFrameRespectsSupersampleOne() throws {
    let image = try renderEmojiFrame("🔵", size: 96, supersample: 1)
    #expect(image.width == 96)
    #expect(image.height == 96)
}
