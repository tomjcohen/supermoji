import CoreGraphics

public enum FadeError: Error, CustomStringConvertible {
    case mismatchedSizes
    case failedToCreateContext

    public var description: String {
        switch self {
        case .mismatchedSizes: "Cannot blend images of different sizes"
        case .failedToCreateContext: "Failed to create graphics context"
        }
    }
}

/// Rasterises an image into a tightly-packed RGBA8 premultiplied-last buffer.
private func rasterize(_ image: CGImage, width: Int, height: Int) throws -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    try buffer.withUnsafeMutableBytes { raw in
        guard let context = CGContext(
            data: raw.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FadeError.failedToCreateContext }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return buffer
}

/// Builds an RGBA8 premultiplied-last image from a tightly-packed buffer.
private func makeImage(from buffer: [UInt8], width: Int, height: Int) throws -> CGImage {
    var mutable = buffer
    return try mutable.withUnsafeMutableBytes { raw -> CGImage in
        guard let context = CGContext(
            data: raw.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { throw FadeError.failedToCreateContext }
        return image
    }
}

/// Renders an emoji to a crisp RGBA8 premultiplied-last frame at `size` pixels.
///
/// The glyph is drawn at `size × supersample` and downscaled with high-quality
/// interpolation. Apple Color Emoji is a bitmap face (native strike ≈160px), so
/// supersampling mainly improves edge anti-aliasing — but routing every frame
/// through one renderer guarantees that a `still` and a `fade` endpoint of the
/// same emoji at the same size are byte-identical.
public func renderEmojiFrame(_ emoji: String, size: Int, supersample: Int = 2) throws -> CGImage {
    let factor = max(1, supersample)
    let rendered = try renderEmoji(emoji, size: size * factor)
    let bytes = try rasterize(rendered, width: size, height: size)
    return try makeImage(from: bytes, width: size, height: size)
}

/// Cross-dissolves two same-sized images by linearly interpolating every channel
/// (including alpha) in premultiplied-alpha space: `out = A·(1−t) + B·t`. The
/// premultiplied lerp keeps the result transparent where neither source covers
/// and opaque where either does — correct over any background. `t` is expected
/// to be the already-eased blend amount.
public func blend(_ a: CGImage, _ b: CGImage, t: Double) throws -> CGImage {
    guard a.width == b.width, a.height == b.height else { throw FadeError.mismatchedSizes }
    let width = a.width, height = a.height
    let bytesA = try rasterize(a, width: width, height: height)
    let bytesB = try rasterize(b, width: width, height: height)

    var out = [UInt8](repeating: 0, count: width * height * 4)
    let inverse = 1 - t
    for i in 0..<out.count {
        let value = Double(bytesA[i]) * inverse + Double(bytesB[i]) * t
        out[i] = UInt8(min(255, max(0, value.rounded())))
    }
    return try makeImage(from: out, width: width, height: height)
}

/// Number of one-way frames (including both endpoints) for a fade.
public func fadeForwardFrames(fps: Int, duration: Double) -> Int {
    max(2, Int((duration * Double(fps)).rounded()))
}

/// Builds the full ping-pong frame sequence for a cross-fade between two emoji.
///
/// Renders each endpoint once via ``renderEmojiFrame(_:size:supersample:)``,
/// then blends one frame per scheduled `t` (after applying `curve`). The result
/// loops seamlessly when written with a forever-looping GIF.
public func makeFadeFrames(
    from a: String, to b: String, curve: EasingCurve, fps: Int, duration: Double, size: Int
) throws -> [CGImage] {
    let forwardFrames = fadeForwardFrames(fps: fps, duration: duration)
    let frameA = try renderEmojiFrame(a, size: size)
    let frameB = try renderEmojiFrame(b, size: size)
    return try fadeTSchedule(forwardFrames: forwardFrames).map { t in
        try blend(frameA, frameB, t: curve.apply(t))
    }
}

/// Linear `t` values (0...1) for a forward-then-back ping-pong fade.
///
/// Forward frames run `t = i/(N-1)` for `i = 0...N-1` (t=0 pure A → t=1 pure B);
/// the reverse half walks `i = N-2...1`, so the two endpoints appear once per
/// cycle — no duplicated turnaround frame and no jump at the loop seam. The
/// returned sequence has `2N - 2` elements. Easing is applied later, at blend
/// time, keeping this schedule pure.
public func fadeTSchedule(forwardFrames n: Int) -> [Double] {
    let count = max(2, n)
    let forward = (0..<count).map { Double($0) / Double(count - 1) }
    guard count > 2 else { return forward }
    let reverse = stride(from: count - 2, through: 1, by: -1).map { Double($0) / Double(count - 1) }
    return forward + reverse
}
