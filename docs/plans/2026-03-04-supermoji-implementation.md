# supermoji Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Swift CLI that renders Apple Color Emoji into animated or static GIFs.

**Architecture:** Swift Package with ArgumentParser for CLI. CoreText/AppKit renders emoji into CGImages, ImageIO assembles them into animated GIFs. Single source file plus tests.

**Tech Stack:** Swift 6, swift-argument-parser, AppKit, CoreGraphics, ImageIO

---

### Task 1: Scaffold Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/Supermoji/Supermoji.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "supermoji",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "supermoji",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/Supermoji"
        ),
        .testTarget(
            name: "SupermojiTests",
            dependencies: ["supermoji"],
            path: "Tests/SupermojiTests"
        ),
    ]
)
```

**Step 2: Create minimal main entry point**

Create `Sources/Supermoji/Supermoji.swift`:

```swift
import ArgumentParser

@main
struct Supermoji: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate animated GIFs from emoji"
    )

    @Argument(help: "Emoji characters to render")
    var emoji: String

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 256

    @Option(name: .long, help: "Frame delay in milliseconds")
    var delay: Int = 500

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        print("supermoji: \(emoji) size=\(size) delay=\(delay) output=\(output)")
    }
}
```

**Step 3: Build to verify scaffold works**

Run: `cd /Users/tomcohen/Code/github.com/tomjcohen/supermoji && swift build`
Expected: BUILD SUCCEEDED

**Step 4: Test the CLI prints something**

Run: `swift run supermoji 😀😃 2>/dev/null`
Expected: `supermoji: 😀😃 size=256 delay=500 output=output.gif`

**Step 5: Commit**

```bash
git add Package.swift Sources/
git commit -m "feat: scaffold Swift package with ArgumentParser CLI"
```

---

### Task 2: Emoji Splitting

**Files:**
- Create: `Sources/Supermoji/EmojiSplitter.swift`
- Create: `Tests/SupermojiTests/EmojiSplitterTests.swift`

**Step 1: Write failing tests**

Create `Tests/SupermojiTests/EmojiSplitterTests.swift`:

```swift
import Testing
@testable import supermoji

@Test func splitSimpleEmoji() {
    let result = splitEmoji("😀😃😄")
    #expect(result == ["😀", "😃", "😄"])
}

@Test func splitSingleEmoji() {
    let result = splitEmoji("🎉")
    #expect(result == ["🎉"])
}

@Test func splitCompoundEmoji() {
    // Skin tone modifier
    let result = splitEmoji("👍🏽👍🏻")
    #expect(result == ["👍🏽", "👍🏻"])
}

@Test func splitFlagEmoji() {
    let result = splitEmoji("🇬🇧🇺🇸")
    #expect(result == ["🇬🇧", "🇺🇸"])
}

@Test func splitZWJEmoji() {
    // Family emoji (ZWJ sequence)
    let result = splitEmoji("👨‍👩‍👧‍👦")
    #expect(result == ["👨‍👩‍👧‍👦"])
}

@Test func splitEmptyString() {
    let result = splitEmoji("")
    #expect(result == [])
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `splitEmoji` not found

**Step 3: Implement emoji splitter**

Create `Sources/Supermoji/EmojiSplitter.swift`:

```swift
/// Splits a string into individual emoji characters, respecting grapheme clusters.
/// This correctly handles compound emoji (skin tones, flags, ZWJ sequences).
func splitEmoji(_ input: String) -> [String] {
    input.map(String.init)
}
```

Swift's `Character` type already represents extended grapheme clusters, so `String.map` gives us correct splitting for free — skin tones, flags, ZWJ sequences all work.

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/Supermoji/EmojiSplitter.swift Tests/
git commit -m "feat: add emoji splitter with grapheme cluster support"
```

---

### Task 3: Emoji Renderer

**Files:**
- Create: `Sources/Supermoji/EmojiRenderer.swift`
- Create: `Tests/SupermojiTests/EmojiRendererTests.swift`

**Step 1: Write failing tests**

Create `Tests/SupermojiTests/EmojiRendererTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import supermoji

@Test func rendersSingleEmojiToImage() throws {
    let image = try renderEmoji("😀", size: 64)
    #expect(image.width == 64)
    #expect(image.height == 64)
}

@Test func rendersAtRequestedSize() throws {
    let image = try renderEmoji("🎉", size: 128)
    #expect(image.width == 128)
    #expect(image.height == 128)
}

@Test func renderedImageHasColorData() throws {
    let image = try renderEmoji("😀", size: 64)
    guard let dataProvider = image.dataProvider, let data = dataProvider.data else {
        Issue.record("No image data")
        return
    }
    let bytes = CFDataGetLength(data)
    // A 64x64 RGBA image should have 64*64*4 = 16384 bytes
    #expect(bytes == 64 * 64 * 4)
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `renderEmoji` not found

**Step 3: Implement renderer**

Create `Sources/Supermoji/EmojiRenderer.swift`:

```swift
import AppKit
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
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/Supermoji/EmojiRenderer.swift Tests/SupermojiTests/EmojiRendererTests.swift
git commit -m "feat: add emoji renderer using CoreText and CoreGraphics"
```

---

### Task 4: GIF Writer

**Files:**
- Create: `Sources/Supermoji/GIFWriter.swift`
- Create: `Tests/SupermojiTests/GIFWriterTests.swift`

**Step 1: Write failing tests**

Create `Tests/SupermojiTests/GIFWriterTests.swift`:

```swift
import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import supermoji

@Test func writesAnimatedGIF() throws {
    let frames = try ["😀", "😃", "😄"].map { try renderEmoji($0, size: 64) }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-animated.gif")

    try writeGIF(frames: frames, delayMs: 500, to: url)

    let data = try Data(contentsOf: url)
    #expect(data.count > 0)

    // Verify it's actually a GIF (magic bytes: GIF89a)
    let magic = data.prefix(6)
    #expect(magic == Data("GIF89a".utf8))

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
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | tail -20`
Expected: FAIL — `writeGIF` not found

**Step 3: Implement GIF writer**

Create `Sources/Supermoji/GIFWriter.swift`:

```swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum GIFError: Error, CustomStringConvertible {
    case failedToCreateDestination
    case failedToFinalize

    var description: String {
        switch self {
        case .failedToCreateDestination: "Failed to create GIF destination"
        case .failedToFinalize: "Failed to finalize GIF file"
        }
    }
}

/// Writes an array of CGImages as an animated (or static) GIF.
func writeGIF(frames: [CGImage], delayMs: Int, to url: URL) throws {
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
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/Supermoji/GIFWriter.swift Tests/SupermojiTests/GIFWriterTests.swift
git commit -m "feat: add GIF writer using ImageIO with animation support"
```

---

### Task 5: Wire Up CLI

**Files:**
- Modify: `Sources/Supermoji/Supermoji.swift`

**Step 1: Update run() to use all components**

Replace the `run()` method in `Sources/Supermoji/Supermoji.swift`:

```swift
import ArgumentParser
import Foundation

@main
struct Supermoji: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate animated GIFs from emoji"
    )

    @Argument(help: "Emoji characters to render")
    var emoji: String

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 256

    @Option(name: .long, help: "Frame delay in milliseconds")
    var delay: Int = 500

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        let characters = splitEmoji(emoji)

        guard !characters.isEmpty else {
            throw ValidationError("No emoji characters provided")
        }

        let frames = try characters.map { try renderEmoji($0, size: size) }
        let outputURL = URL(fileURLWithPath: output)
        let effectiveDelay = characters.count == 1 ? 0 : delay

        try writeGIF(frames: frames, delayMs: effectiveDelay, to: outputURL)

        if characters.count == 1 {
            print("Wrote static GIF: \(output) (\(size)x\(size))")
        } else {
            print("Wrote animated GIF: \(output) (\(characters.count) frames, \(size)x\(size), \(delay)ms delay)")
        }
    }
}
```

**Step 2: Build**

Run: `swift build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Test end-to-end with animated emoji**

Run: `swift run supermoji 😀😃😄😁😆 -o /tmp/smiley.gif 2>/dev/null && file /tmp/smiley.gif`
Expected: `/tmp/smiley.gif: GIF image data, version 89a, 256 x 256`

**Step 4: Test end-to-end with single emoji**

Run: `swift run supermoji 🎉 -o /tmp/party.gif 2>/dev/null && file /tmp/party.gif`
Expected: `/tmp/party.gif: GIF image data, version 89a, 256 x 256`

**Step 5: Test with custom flags**

Run: `swift run supermoji 🤙👍 --size 512 --delay 200 -o /tmp/thumbs.gif 2>/dev/null && file /tmp/thumbs.gif`
Expected: `/tmp/thumbs.gif: GIF image data, version 89a, 512 x 512`

**Step 6: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 7: Commit**

```bash
git add Sources/Supermoji/Supermoji.swift
git commit -m "feat: wire up CLI to render and write emoji GIFs"
```

---

### Task 6: Add .gitignore and clean up

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```
.build/
.swiftpm/
*.xcodeproj/
output.gif
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for Swift package"
```
