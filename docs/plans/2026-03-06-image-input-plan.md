# Image Input Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow images (PNG, JPEG, etc.) as frames in the GIF sequence, in both CLI and Mac app.

**Architecture:** New `FrameSource` enum (`.emoji` / `.image`) in SupermojiKit with an `ImageLoader` that loads and scales images via `CGImageSource`. CLI accepts mixed emoji/file-path arguments. Mac app replaces text field with a visual sequence strip.

**Tech Stack:** Swift 6, CoreGraphics, ImageIO, SwiftUI (macOS 14+), Swift Testing, ArgumentParser

---

### Task 1: ImageLoader — Load and Scale Images

**Files:**
- Create: `Sources/SupermojiKit/ImageLoader.swift`
- Create: `Tests/SupermojiTests/ImageLoaderTests.swift`

**Step 1: Write the failing tests**

In `Tests/SupermojiTests/ImageLoaderTests.swift`:

```swift
import Testing
import Foundation
import CoreGraphics
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
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ImageLoader 2>&1 | tail -20`
Expected: compilation error — `loadImage` and `ImageLoadError` not defined

**Step 3: Write minimal implementation**

In `Sources/SupermojiKit/ImageLoader.swift`:

```swift
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
        kCGImageSourceThumbnailMaxPixelSize: max(size, size),
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
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ImageLoader 2>&1 | tail -20`
Expected: 3 tests pass

**Step 5: Commit**

```bash
git add Sources/SupermojiKit/ImageLoader.swift Tests/SupermojiTests/ImageLoaderTests.swift
git commit -m "feat: add ImageLoader for loading and scaling image files"
```

---

### Task 2: FrameSource Enum and renderFrame

**Files:**
- Create: `Sources/SupermojiKit/FrameSource.swift`
- Create: `Tests/SupermojiTests/FrameSourceTests.swift`

**Step 1: Write the failing tests**

In `Tests/SupermojiTests/FrameSourceTests.swift`:

```swift
import Testing
import Foundation
import CoreGraphics
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
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter FrameSource 2>&1 | tail -20`
Expected: compilation error — `FrameSource` and `renderFrame` not defined

**Step 3: Write minimal implementation**

In `Sources/SupermojiKit/FrameSource.swift`:

```swift
import Foundation
import CoreGraphics

public enum FrameSource: Sendable {
    case emoji(String)
    case image(URL)
}

/// Renders a single frame source to a CGImage at the given pixel size.
public func renderFrame(_ source: FrameSource, size: Int) throws -> CGImage {
    switch source {
    case .emoji(let character):
        return try renderEmoji(character, size: size)
    case .image(let url):
        return try loadImage(from: url, size: size)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter FrameSource 2>&1 | tail -20`
Expected: 2 tests pass

**Step 5: Run full test suite**

Run: `swift test 2>&1 | tail -15`
Expected: all 16 tests pass (11 existing + 3 ImageLoader + 2 FrameSource)

**Step 6: Commit**

```bash
git add Sources/SupermojiKit/FrameSource.swift Tests/SupermojiTests/FrameSourceTests.swift
git commit -m "feat: add FrameSource enum and renderFrame dispatch"
```

---

### Task 3: CLI — Mixed Arguments

**Files:**
- Modify: `Sources/Supermoji/Supermoji.swift`

**Step 1: Update CLI to accept mixed inputs**

Replace the full contents of `Sources/Supermoji/Supermoji.swift`:

```swift
import ArgumentParser
import Foundation
import SupermojiKit

@main
struct Supermoji: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate animated GIFs from emoji and images"
    )

    @Argument(help: "Emoji characters and/or image file paths to include as frames")
    var inputs: [String]

    @Option(name: .long, help: "Size in pixels (square)")
    var size: Int = 256

    @Option(name: .long, help: "Frame delay in milliseconds")
    var delay: Int = 500

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "output.gif"

    mutating func run() throws {
        let sources = parseInputs(inputs)

        guard !sources.isEmpty else {
            throw ValidationError("No emoji or image inputs provided")
        }

        let frames = try sources.map { try renderFrame($0, size: size) }
        let outputURL = URL(fileURLWithPath: output)
        let effectiveDelay = frames.count == 1 ? 0 : delay

        try writeGIF(frames: frames, delayMs: effectiveDelay, to: outputURL)

        if frames.count == 1 {
            print("Wrote static GIF: \(output) (\(size)x\(size))")
        } else {
            print("Wrote animated GIF: \(output) (\(frames.count) frames, \(size)x\(size), \(delay)ms delay)")
        }
    }
}

/// Parses CLI arguments into frame sources.
/// If an argument is a path to an existing file, it becomes `.image`.
/// Otherwise it's treated as emoji text and split into grapheme clusters.
func parseInputs(_ inputs: [String]) -> [FrameSource] {
    inputs.flatMap { input -> [FrameSource] in
        if FileManager.default.fileExists(atPath: input) {
            return [.image(URL(fileURLWithPath: input))]
        } else {
            return splitEmoji(input).map { .emoji($0) }
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: build succeeds

**Step 3: Manual smoke test**

Run: `swift run supermoji 😀😃😄 2>&1`
Expected: `Wrote animated GIF: output.gif (3 frames, 256x256, 500ms delay)`

**Step 4: Run full test suite**

Run: `swift test 2>&1 | tail -15`
Expected: all 16 tests pass

**Step 5: Commit**

```bash
git add Sources/Supermoji/Supermoji.swift
git commit -m "feat: CLI accepts mixed emoji and image file path arguments"
```

---

### Task 4: Mac App ViewModel — Replace emojiText with Items

**Files:**
- Modify: `Sources/SupermojiApp/SupermojiViewModel.swift`

**Step 1: Update ViewModel**

This is the Mac app (built via xcodegen, not SPM), so no automated tests. Replace the full contents of `Sources/SupermojiApp/SupermojiViewModel.swift`:

```swift
import SwiftUI
@preconcurrency import AppKit
import SupermojiKit
import CoreGraphics
import UniformTypeIdentifiers

enum EmojiSize: Int, CaseIterable {
    case small = 128
    case medium = 256
    case large = 512

    var label: String {
        "\(rawValue)px"
    }
}

enum EmojiSpeed: Int, CaseIterable {
    case fast = 250
    case medium = 500
    case slow = 1000

    var label: String {
        switch self {
        case .fast: "Fast"
        case .medium: "Medium"
        case .slow: "Slow"
        }
    }
}

@MainActor
final class SupermojiViewModel: ObservableObject {
    @Published var items: [FrameSource] = []
    @Published var size: EmojiSize = .medium
    @Published var speed: EmojiSpeed = .medium
    @Published var frames: [NSImage] = []
    @Published var currentFrameIndex: Int = 0
    @Published var copied: Bool = false

    private var cgFrames: [CGImage] = []
    private var timer: Timer?
    private var renderTask: Task<Void, Never>?

    var currentFrame: NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[currentFrameIndex % frames.count]
    }

    func addEmoji(_ text: String) {
        let characters = splitEmoji(text)
        items.append(contentsOf: characters.map { .emoji($0) })
        render()
    }

    func addImages(urls: [URL]) {
        items.append(contentsOf: urls.map { .image($0) })
        render()
    }

    func removeItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        render()
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        render()
    }

    func render() {
        renderTask?.cancel()
        timer?.invalidate()
        timer = nil

        guard !items.isEmpty else {
            frames = []
            cgFrames = []
            currentFrameIndex = 0
            return
        }

        let pixelSize = size.rawValue
        let currentItems = items

        renderTask = Task {
            var renderedCG: [CGImage] = []
            var renderedNS: [NSImage] = []
            for item in currentItems {
                guard !Task.isCancelled else { return }
                if let cgImage = try? renderFrame(item, size: pixelSize) {
                    renderedCG.append(cgImage)
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelSize, height: pixelSize))
                    renderedNS.append(nsImage)
                }
            }

            guard !Task.isCancelled else { return }

            self.cgFrames = renderedCG
            self.frames = renderedNS
            self.currentFrameIndex = 0
            self.startAnimation()
        }
    }

    func startAnimation() {
        timer?.invalidate()
        guard frames.count > 1 else { return }

        let interval = Double(speed.rawValue) / 1000.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.frames.isEmpty else { return }
                self.currentFrameIndex = (self.currentFrameIndex + 1) % self.frames.count
            }
        }
    }

    func copyToClipboard() {
        guard !cgFrames.isEmpty else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("supermoji-clipboard.gif")
        let framesToWrite = cgFrames
        let delayMs = framesToWrite.count == 1 ? 0 : speed.rawValue

        Task {
            do {
                try writeGIF(frames: framesToWrite, delayMs: delayMs, to: tempURL)
                let data = try Data(contentsOf: tempURL)

                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setData(data, forType: .init(UTType.gif.identifier))

                self.copied = true
                try? await Task.sleep(for: .seconds(1.5))
                self.copied = false
            } catch {
                // silently fail for now
            }
        }
    }

    func save() {
        guard !cgFrames.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = "supermoji.gif"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let framesToWrite = cgFrames
        let delayMs = framesToWrite.count == 1 ? 0 : speed.rawValue

        Task {
            do {
                try writeGIF(frames: framesToWrite, delayMs: delayMs, to: url)
            } catch {
                // TODO: show alert on failure
            }
        }
    }
}
```

**Step 2: Build SupermojiKit to verify no regressions**

Run: `swift build 2>&1 | tail -5`
Expected: build succeeds (Mac app isn't built via SPM, so this only checks SupermojiKit + CLI)

**Step 3: Commit**

```bash
git add Sources/SupermojiApp/SupermojiViewModel.swift
git commit -m "feat: ViewModel uses FrameSource items instead of emoji text"
```

---

### Task 5: Mac App UI — Sequence Strip

**Files:**
- Modify: `Sources/SupermojiApp/ContentView.swift`

**Step 1: Replace text field with sequence builder UI**

Replace the full contents of `Sources/SupermojiApp/ContentView.swift`:

```swift
import SwiftUI
import SupermojiKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = SupermojiViewModel()
    @State private var emojiInput: String = ""
    @State private var draggedItem: Int?

    var body: some View {
        VStack(spacing: 20) {
            // Sequence strip
            sequenceStrip

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quinary)

                if let frame = viewModel.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .padding(32)
                } else {
                    Text("Add emoji or images to get started")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                }
            }
            .frame(height: 220)

            // Controls
            VStack(spacing: 12) {
                LabeledPicker(title: "Size", selection: $viewModel.size) {
                    ForEach(EmojiSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .onChange(of: viewModel.size) {
                    viewModel.render()
                }

                LabeledPicker(title: "Speed", selection: $viewModel.speed) {
                    ForEach(EmojiSpeed.allCases, id: \.self) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .onChange(of: viewModel.speed) {
                    viewModel.startAnimation()
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: viewModel.copyToClipboard) {
                    Label(viewModel.copied ? "Copied!" : "Copy",
                          systemImage: viewModel.copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.frames.isEmpty)

                Button(action: viewModel.save) {
                    Label("Save GIF", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.frames.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var sequenceStrip: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                        frameSourceTile(item, at: index)
                    }

                    addImageButton
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(height: 52)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }

            // Emoji text input
            HStack(spacing: 8) {
                TextField("Type emoji...", text: $emojiInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit {
                        guard !emojiInput.isEmpty else { return }
                        viewModel.addEmoji(emojiInput)
                        emojiInput = ""
                    }

                Text("press return to add")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func frameSourceTile(_ item: FrameSource, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .emoji(let char):
                    Text(char)
                        .font(.system(size: 24))
                case .image(let url):
                    if let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))

            Button {
                viewModel.removeItem(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .draggable(String(index)) {
            Text(itemLabel(item))
                .padding(4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
        .dropDestination(for: String.self) { dropped, _ in
            guard let sourceStr = dropped.first,
                  let sourceIndex = Int(sourceStr),
                  sourceIndex != index else { return false }
            withAnimation {
                viewModel.items.move(
                    fromOffsets: IndexSet(integer: sourceIndex),
                    toOffset: sourceIndex < index ? index + 1 : index
                )
                viewModel.render()
            }
            return true
        }
    }

    private var addImageButton: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
            panel.allowsMultipleSelection = true
            guard panel.runModal() == .OK else { return }
            viewModel.addImages(urls: panel.urls)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(.background, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                viewModel.addImages(urls: urls)
            }
        }
        return true
    }

    private func itemLabel(_ item: FrameSource) -> String {
        switch item {
        case .emoji(let char): char
        case .image(let url): url.lastPathComponent
        }
    }
}

struct LabeledPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Picker(title, selection: $selection) {
                content()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
```

**Step 2: Build CLI + library to verify no regressions**

Run: `swift build 2>&1 | tail -5`
Expected: build succeeds

**Step 3: Run full test suite**

Run: `swift test 2>&1 | tail -15`
Expected: all 16 tests pass

**Step 4: Commit**

```bash
git add Sources/SupermojiApp/ContentView.swift
git commit -m "feat: replace text field with sequence strip UI for mixed emoji and images"
```

---

### Task 6: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update architecture section**

Add `FrameSource.swift` and `ImageLoader.swift` to the SupermojiKit bullet list in the Architecture section. Update the CLI description to mention mixed inputs.

Add after the `GIFWriter.swift` line:
```
- `Sources/SupermojiKit/FrameSource.swift` — `FrameSource` enum (`.emoji`/`.image`) and `renderFrame(_:size:)` dispatcher.
- `Sources/SupermojiKit/ImageLoader.swift` — `loadImage(from:size:)` loads and scales image files via ImageIO.
```

Update the CLI line to:
```
**supermoji** (CLI executable) — `Sources/Supermoji/Supermoji.swift`. ArgumentParser entry point, accepts mixed emoji and image file path arguments. Depends on SupermojiKit.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with new SupermojiKit files"
```
