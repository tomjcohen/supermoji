#!/usr/bin/env swift

// Generates Resources/AppIcon.icns from the star-struck emoji.
// Uses CoreText rendering (same approach as EmojiRenderer.swift, inlined for standalone use).
// Run: swift scripts/generate-icon.swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO

// MARK: - Emoji Rendering (inlined from EmojiRenderer.swift)

func renderEmoji(_ emoji: String, size: Int) -> CGImage? {
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
        return nil
    }

    let fontSize = cgSize * 0.85
    let font = NSFont.systemFont(ofSize: fontSize)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attrString = NSAttributedString(string: emoji, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attrString)

    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let xOffset = (cgSize - bounds.width) / 2 - bounds.origin.x
    let yOffset = (cgSize - bounds.height) / 2 - bounds.origin.y

    context.textPosition = CGPoint(x: xOffset, y: yOffset)
    CTLineDraw(line, context)

    return context.makeImage()
}

// MARK: - PNG Writing

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// MARK: - Main

let emoji = "\u{1F929}" // star-struck

// Resolve paths relative to the script's repo root
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptURL.deletingLastPathComponent()
let resourcesDir = repoRoot.appendingPathComponent("Resources")
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")
let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")

// Create the .iconset directory
let fm = FileManager.default
try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// Mapping: (filename, pixel size)
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

// Render each size and write PNG
var renderedSizes = Set<Int>()
var cache: [Int: CGImage] = [:]

for (filename, pixelSize) in entries {
    let image: CGImage
    if let cached = cache[pixelSize] {
        image = cached
    } else {
        guard let rendered = renderEmoji(emoji, size: pixelSize) else {
            fputs("Error: failed to render emoji at \(pixelSize)px\n", stderr)
            exit(1)
        }
        cache[pixelSize] = rendered
        image = rendered
    }

    let fileURL = iconsetDir.appendingPathComponent(filename)
    guard writePNG(image, to: fileURL) else {
        fputs("Error: failed to write \(filename)\n", stderr)
        exit(1)
    }
    renderedSizes.insert(pixelSize)
}

print("Rendered \(entries.count) icons into \(iconsetDir.path)")

// Run iconutil to convert .iconset to .icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", icnsURL.path, iconsetDir.path]

let pipe = Pipe()
process.standardError = pipe

try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
    let errorMessage = String(data: errorData, encoding: .utf8) ?? "unknown error"
    fputs("iconutil failed: \(errorMessage)\n", stderr)
    exit(1)
}

// Clean up the .iconset directory
try? fm.removeItem(at: iconsetDir)

print("Generated \(icnsURL.path)")
