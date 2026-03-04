# Supermoji Mac App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a SwiftUI Mac app to supermoji that lets non-technical users generate animated GIFs from emoji.

**Architecture:** Extract existing core logic into a `SupermojiKit` library target. Add a SwiftUI app target that depends on it. Thin Xcode project for app bundle, signing, and notarisation.

**Tech Stack:** Swift 6, SwiftUI (macOS 13+), CoreText, ImageIO, Xcode project for `.app` bundle.

---

### Task 1: Extract SupermojiKit library target

Move the three core files into a library target so both the CLI and app can share them.

**Files:**
- Create: `Sources/SupermojiKit/EmojiSplitter.swift` (move from `Sources/Supermoji/`)
- Create: `Sources/SupermojiKit/EmojiRenderer.swift` (move from `Sources/Supermoji/`)
- Create: `Sources/SupermojiKit/GIFWriter.swift` (move from `Sources/Supermoji/`)
- Modify: `Sources/Supermoji/Supermoji.swift` — add `import SupermojiKit`
- Modify: `Package.swift` — add library target, update dependencies

**Step 1: Create the SupermojiKit directory and move files**

```bash
mkdir -p Sources/SupermojiKit
git mv Sources/Supermoji/EmojiSplitter.swift Sources/SupermojiKit/
git mv Sources/Supermoji/EmojiRenderer.swift Sources/SupermojiKit/
git mv Sources/Supermoji/GIFWriter.swift Sources/SupermojiKit/
```

**Step 2: Make functions and types public in all three files**

In `Sources/SupermojiKit/EmojiSplitter.swift`:
```swift
/// Splits a string into individual emoji characters, respecting grapheme clusters.
/// This correctly handles compound emoji (skin tones, flags, ZWJ sequences).
public func splitEmoji(_ input: String) -> [String] {
    input.map(String.init)
}
```

In `Sources/SupermojiKit/EmojiRenderer.swift`, make `RenderError` and `renderEmoji` public:
```swift
public enum RenderError: Error, CustomStringConvertible {
    // ... (unchanged cases)
}

public func renderEmoji(_ emoji: String, size: Int) throws -> CGImage {
    // ... (unchanged body)
}
```

In `Sources/SupermojiKit/GIFWriter.swift`, make `GIFError` and `writeGIF` public:
```swift
public enum GIFError: Error, CustomStringConvertible {
    // ... (unchanged cases)
}

public func writeGIF(frames: [CGImage], delayMs: Int, to url: URL) throws {
    // ... (unchanged body)
}
```

**Step 3: Update Package.swift**

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
        .target(
            name: "SupermojiKit",
            path: "Sources/SupermojiKit"
        ),
        .executableTarget(
            name: "supermoji",
            dependencies: [
                "SupermojiKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/Supermoji"
        ),
        .testTarget(
            name: "SupermojiTests",
            dependencies: ["SupermojiKit"],
            path: "Tests/SupermojiTests"
        ),
    ]
)
```

**Step 4: Add import to CLI entry point**

In `Sources/Supermoji/Supermoji.swift`, add at the top:
```swift
import SupermojiKit
```

**Step 5: Update test imports**

In all test files (`Tests/SupermojiTests/*.swift`), change:
```swift
@testable import supermoji
```
to:
```swift
@testable import SupermojiKit
```

**Step 6: Build and run tests**

Run: `swift build`
Expected: BUILD SUCCEEDED

Run: `swift test`
Expected: All existing tests pass

**Step 7: Commit**

```bash
git add -A
git commit -m "refactor: extract SupermojiKit library target"
```

---

### Task 2: Add SupermojiApp SwiftUI target

Create the SwiftUI app with a view model and the main window.

**Files:**
- Create: `Sources/SupermojiApp/SupermojiApp.swift` — app entry point
- Create: `Sources/SupermojiApp/ContentView.swift` — main UI
- Create: `Sources/SupermojiApp/SupermojiViewModel.swift` — rendering logic
- Modify: `Package.swift` — add app target

**Step 1: Update Package.swift to add the app target**

Add to the targets array:
```swift
.executableTarget(
    name: "SupermojiApp",
    dependencies: ["SupermojiKit"],
    path: "Sources/SupermojiApp"
),
```

**Step 2: Create the app entry point**

Create `Sources/SupermojiApp/SupermojiApp.swift`:
```swift
import SwiftUI

@main
struct SupermojiMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
```

**Step 3: Create the view model**

Create `Sources/SupermojiApp/SupermojiViewModel.swift`:
```swift
import SwiftUI
import SupermojiKit
import CoreGraphics

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
    @Published var emojiText: String = ""
    @Published var size: EmojiSize = .medium
    @Published var speed: EmojiSpeed = .medium
    @Published var frames: [NSImage] = []
    @Published var currentFrameIndex: Int = 0
    @Published var isRendering: Bool = false

    private var timer: Timer?
    private var renderTask: Task<Void, Never>?

    var currentFrame: NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[currentFrameIndex % frames.count]
    }

    func render() {
        renderTask?.cancel()
        timer?.invalidate()
        timer = nil

        let characters = splitEmoji(emojiText)
        guard !characters.isEmpty else {
            frames = []
            currentFrameIndex = 0
            return
        }

        isRendering = true
        let pixelSize = size.rawValue

        renderTask = Task {
            var rendered: [NSImage] = []
            for char in characters {
                guard !Task.isCancelled else { return }
                if let cgImage = try? renderEmoji(char, size: pixelSize) {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelSize, height: pixelSize))
                    rendered.append(nsImage)
                }
            }

            guard !Task.isCancelled else { return }

            self.frames = rendered
            self.currentFrameIndex = 0
            self.isRendering = false
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

    func save() {
        let characters = splitEmoji(emojiText)
        guard !characters.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = "supermoji.gif"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let pixelSize = size.rawValue
        let delayMs = characters.count == 1 ? 0 : speed.rawValue

        Task {
            do {
                let cgFrames = try characters.map { try renderEmoji($0, size: pixelSize) }
                try writeGIF(frames: cgFrames, delayMs: delayMs, to: url)
            } catch {
                // TODO: show alert on failure
            }
        }
    }
}
```

**Step 4: Create the content view**

Create `Sources/SupermojiApp/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SupermojiViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Emoji input
            TextField("Type emoji here...", text: $viewModel.emojiText)
                .textFieldStyle(.roundedBorder)
                .font(.title)
                .onChange(of: viewModel.emojiText) {
                    viewModel.render()
                }

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)

                if let frame = viewModel.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                } else {
                    Text("Your emoji will appear here")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
            }
            .frame(height: 256)

            // Controls
            HStack {
                Picker("Size", selection: $viewModel.size) {
                    ForEach(EmojiSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.size) {
                    viewModel.render()
                }

                Picker("Speed", selection: $viewModel.speed) {
                    ForEach(EmojiSpeed.allCases, id: \.self) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.speed) {
                    viewModel.render()
                }
            }

            // Save button
            Button(action: viewModel.save) {
                Label("Save GIF", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.frames.isEmpty)
        }
        .padding(24)
        .frame(width: 360)
    }
}
```

**Step 5: Build the app target**

Run: `swift build --target SupermojiApp`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add SwiftUI Mac app target"
```

---

### Task 3: Generate app icon from 🤩 emoji

Use the existing renderer to create the app icon.

**Files:**
- Create: `Resources/AppIcon.icns`

**Step 1: Write a script to generate the icon**

Create `scripts/generate-icon.swift`:
```swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Inline the renderer to avoid module import issues in a script
@preconcurrency import AppKit

func renderIcon(_ emoji: String, size: Int) throws -> CGImage {
    let cgSize = CGFloat(size)
    guard let context = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Failed to create context") }

    let fontSize = cgSize * 0.85
    let font = NSFont.systemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let attrStr = NSAttributedString(string: emoji, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let xOffset = (cgSize - bounds.width) / 2 - bounds.origin.x
    let yOffset = (cgSize - bounds.height) / 2 - bounds.origin.y
    context.textPosition = CGPoint(x: xOffset, y: yOffset)
    CTLineDraw(line, context)
    return context.makeImage()!
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("supermoji-icon")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

for size in sizes {
    let image = try renderIcon("🤩", size: size)
    let url = tempDir.appendingPathComponent("icon_\(size)x\(size).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

print("PNGs written to: \(tempDir.path)")
print("Convert to .icns with: iconutil --convert icns <iconset>")
```

**Step 2: Run the script and create the .icns**

Run: `swift scripts/generate-icon.swift`

Then create the `.iconset` directory with required naming, and:
```bash
mkdir -p Resources
iconutil --convert icns /path/to/supermoji.iconset -o Resources/AppIcon.icns
```

Note: The executing agent will need to handle the iconset naming conventions (`icon_16x16.png`, `icon_16x16@2x.png`, etc.) during execution.

**Step 3: Commit**

```bash
git add Resources/AppIcon.icns scripts/generate-icon.swift
git commit -m "feat: generate app icon from 🤩 emoji"
```

---

### Task 4: Create Xcode project wrapper

Create a minimal Xcode project that wraps the SPM package to produce a signed `.app` bundle.

**Files:**
- Create: `SupermojiApp.xcodeproj/` — Xcode project
- Create: `SupermojiApp/Info.plist`
- Create: `SupermojiApp/SupermojiApp.entitlements`
- Create: `SupermojiApp/Assets.xcassets/AppIcon.appiconset/`

**Step 1: Create the Xcode project**

This step requires Xcode. Create a new macOS App project via:
```bash
mkdir -p SupermojiApp
```

Create `SupermojiApp/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Supermoji</string>
    <key>CFBundleDisplayName</key>
    <string>Supermoji</string>
    <key>CFBundleIdentifier</key>
    <string>com.tomjcohen.supermoji</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>SupermojiApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

Create `SupermojiApp/SupermojiApp.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

**Step 2: Set up the asset catalogue with the app icon**

```bash
mkdir -p SupermojiApp/Assets.xcassets/AppIcon.appiconset
```

Copy the generated icon PNGs and create a `Contents.json` referencing them.

**Step 3: Generate the Xcode project**

The simplest approach: create the `.xcodeproj` using `xcodegen` or manually. Since this is a thin wrapper, the executing agent should create the project file that:
- References the local Swift package
- Sets the SupermojiApp executable as the main target
- Configures code signing identity and team
- Sets the entitlements and Info.plist

**Step 4: Build with Xcode**

Run: `xcodebuild -project SupermojiApp.xcodeproj -scheme SupermojiApp -configuration Release build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Xcode project for app bundle and signing"
```

---

### Task 5: Add notarisation and DMG build script

Create a script to build, sign, notarise, and package into a DMG.

**Files:**
- Create: `scripts/build-dmg.sh`

**Step 1: Create the build script**

Create `scripts/build-dmg.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCHEME="SupermojiApp"
BUILD_DIR=".build/release-app"
APP_NAME="Supermoji.app"
DMG_NAME="Supermoji.dmg"

echo "Building..."
xcodebuild -project SupermojiApp.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"

echo "Signing..."
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: YOUR_TEAM" \
  --options runtime \
  "$APP_PATH"

echo "Creating DMG..."
hdiutil create -volname "Supermoji" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_NAME"

echo "Signing DMG..."
codesign --sign "Developer ID Application: YOUR_TEAM" "$DMG_NAME"

echo "Notarising..."
xcrun notarytool submit "$DMG_NAME" \
  --keychain-profile "notarytool-profile" \
  --wait

echo "Stapling..."
xcrun stapler staple "$DMG_NAME"

echo "Done: $DMG_NAME"
```

Note: `YOUR_TEAM` and `notarytool-profile` need to be replaced with actual signing identity and notarisation credentials during execution.

**Step 2: Make executable**

```bash
chmod +x scripts/build-dmg.sh
```

**Step 3: Commit**

```bash
git add scripts/build-dmg.sh
git commit -m "feat: add DMG build and notarisation script"
```

---

### Task 6: Test the full flow end-to-end

**Step 1: Build and run the app**

Run: `swift build --target SupermojiApp && .build/debug/SupermojiApp`
Expected: Window appears with emoji text field, preview area, controls, and save button.

**Step 2: Test emoji input**

Type `😀😃😄` into the text field.
Expected: Animated preview cycles through the three emoji.

**Step 3: Test size and speed controls**

Change size to 512px, speed to Fast.
Expected: Preview re-renders at larger size, animation speeds up.

**Step 4: Test save**

Click Save GIF, choose a location.
Expected: GIF file is written and playable.

**Step 5: Test CLI still works**

Run: `swift run supermoji 😀😃😄`
Expected: `output.gif` is written as before.

**Step 6: Final commit**

```bash
git commit --allow-empty -m "test: verify end-to-end Mac app flow"
```
