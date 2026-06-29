import Testing
import CoreGraphics
@testable import SupermojiKit

/// Builds a solid image whose stored bytes are exactly the given premultiplied RGBA.
private func solidImage(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8, size: Int = 4) -> CGImage {
    var buf = [UInt8](repeating: 0, count: size * size * 4)
    for px in 0..<(size * size) {
        buf[px * 4 + 0] = r
        buf[px * 4 + 1] = g
        buf[px * 4 + 2] = b
        buf[px * 4 + 3] = a
    }
    let ctx = CGContext(
        data: &buf, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return ctx.makeImage()!
}

/// Reads the top-left pixel's stored premultiplied RGBA bytes.
private func firstPixel(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(
        data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return Array(buf[0..<4])
}

@Test func blendAtZeroEqualsFirstImage() throws {
    let a = solidImage(255, 0, 0, 255)
    let b = solidImage(0, 0, 255, 255)
    let result = try blend(a, b, t: 0)
    #expect(firstPixel(result) == [255, 0, 0, 255])
}

@Test func blendAtOneEqualsSecondImage() throws {
    let a = solidImage(255, 0, 0, 255)
    let b = solidImage(0, 0, 255, 255)
    let result = try blend(a, b, t: 1)
    #expect(firstPixel(result) == [0, 0, 255, 255])
}

@Test func blendAtHalfIsMidpointColour() throws {
    let a = solidImage(255, 0, 0, 255)
    let b = solidImage(0, 0, 255, 255)
    let result = try blend(a, b, t: 0.5)
    let px = firstPixel(result)
    #expect(abs(Int(px[0]) - 128) <= 1)
    #expect(px[1] == 0)
    #expect(abs(Int(px[2]) - 128) <= 1)
    #expect(px[3] == 255)
}

@Test func blendInterpolatesAlpha() throws {
    let opaque = solidImage(255, 255, 255, 255)
    let clear = solidImage(0, 0, 0, 0)
    let result = try blend(opaque, clear, t: 0.5)
    let px = firstPixel(result)
    // Premultiplied lerp: every channel including alpha halves.
    for channel in px {
        #expect(abs(Int(channel) - 128) <= 1)
    }
}
