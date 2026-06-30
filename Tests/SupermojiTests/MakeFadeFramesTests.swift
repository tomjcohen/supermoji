import Testing
import CoreGraphics
@testable import SupermojiKit

private func allBytes(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(
        data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf
}

@Test func makeFadeFramesHasPingPongCount() throws {
    // N = round(0.6 * 20) = 12 → 2N-2 = 22.
    let frames = try makeFadeFrames(from: "⚪", to: "🔵", curve: .linear, fps: 20, duration: 0.6, size: 64)
    #expect(frames.count == 22)
}

@Test func fadeForwardFramesNeverBelowThree() {
    // A fade-and-return needs start→mid→end; fewer can't ping-pong back.
    #expect(fadeForwardFrames(fps: 1, duration: 0.001) == 3)
    #expect(fadeForwardFrames(fps: 20, duration: 0.1) == 3)   // round(2.0)=2, floored to 3
    #expect(fadeForwardFrames(fps: 20, duration: 0.6) == 12)  // normal case unaffected
}

@Test func makeFadeFramesAlwaysIncludesReturnLeg() throws {
    // Even the shortest fade must walk back, not hard-cut B→A on loop.
    let frames = try makeFadeFrames(from: "⚪", to: "🔵", curve: .linear, fps: 1, duration: 0.001, size: 64)
    #expect(frames.count == 4) // minimum N=3 → 2N-2
    // The final frame is the return mid (== forward mid), not the B endpoint.
    #expect(allBytes(frames.last!) == allBytes(frames[1]))
    #expect(allBytes(frames.last!) != allBytes(frames[2]))
}

@Test func makeFadeFramesEndpointsMatchRenderedEmoji() throws {
    let size = 64
    let frames = try makeFadeFrames(from: "⚪", to: "🔵", curve: .easeInOut, fps: 20, duration: 0.6, size: size)
    // Endpoints are pure A / pure B regardless of curve (eased 0→0, 1→1).
    #expect(allBytes(frames[0]) == allBytes(try renderEmojiFrame("⚪", size: size)))
    #expect(allBytes(frames[11]) == allBytes(try renderEmojiFrame("🔵", size: size))) // index N-1
}

@Test func stillRenderMatchesFadeEndpointBytes() throws {
    // The whole point: a still and a fade endpoint of the same emoji are identical.
    let size = 128
    let still = try renderEmojiFrame("🔵", size: size)
    let frames = try makeFadeFrames(from: "⚪", to: "🔵", curve: .linear, fps: 20, duration: 0.6, size: size)
    #expect(allBytes(still) == allBytes(frames[11]))
}

@Test func makeFadeFramesMidFrameDiffersFromEndpoints() throws {
    let frames = try makeFadeFrames(from: "⚪", to: "🔵", curve: .linear, fps: 20, duration: 0.6, size: 64)
    let mid = allBytes(frames[6])
    #expect(mid != allBytes(frames[0]))
    #expect(mid != allBytes(frames[11]))
}
