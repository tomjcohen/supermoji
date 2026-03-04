import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import SupermojiKit

@Test func writesAnimatedGIF() throws {
    let frames = try ["😀", "😃", "😄"].map { try renderEmoji($0, size: 64) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-animated.gif")

    try writeGIF(frames: frames, delayMs: 500, to: url)

    let data = try Data(contentsOf: url)
    #expect(data.count > 0)

    // Verify it's actually a GIF (magic bytes: GIF87a or GIF89a)
    let magic = data.prefix(6)
    let isGIF = magic == Data("GIF87a".utf8) || magic == Data("GIF89a".utf8)
    #expect(isGIF, "Expected GIF magic bytes, got: \(Array(magic))")

    // Verify it has multiple frames
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        Issue.record("Failed to read GIF back")
        return
    }
    #expect(CGImageSourceGetCount(source) == 3)

    try FileManager.default.removeItem(at: url)
}

@Test func writesSingleFrameGIF() throws {
    let frame = try renderEmoji("🎉", size: 64)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-static.gif")

    try writeGIF(frames: [frame], delayMs: 0, to: url)

    let data = try Data(contentsOf: url)
    #expect(data.count > 0)

    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        Issue.record("Failed to read GIF back")
        return
    }
    #expect(CGImageSourceGetCount(source) == 1)

    try FileManager.default.removeItem(at: url)
}
