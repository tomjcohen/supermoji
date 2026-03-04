# supermoji

Swift CLI that generates animated or static GIFs from emoji, using Apple Color Emoji.

## Build & Test

```bash
swift build          # build
swift test           # run all tests
swift run supermoji 😀😃😄  # run with defaults (256px, 500ms, output.gif)
```

## Architecture

Four source files, each with a single responsibility:

- `Sources/Supermoji/Supermoji.swift` — CLI entry point (ArgumentParser). Parses args, orchestrates pipeline.
- `Sources/Supermoji/EmojiSplitter.swift` — `splitEmoji(_:)` splits input string into grapheme clusters.
- `Sources/Supermoji/EmojiRenderer.swift` — `renderEmoji(_:size:)` renders one emoji to a CGImage via CoreText/AppKit.
- `Sources/Supermoji/GIFWriter.swift` — `writeGIF(frames:delayMs:to:)` assembles CGImages into a GIF via ImageIO.

## Key Conventions

- macOS-only (depends on AppKit for colour emoji rendering)
- Swift 6 with strict concurrency — uses `@preconcurrency import AppKit` for NSFont/NSAttributedString
- Tests use Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- All functions are free functions (no classes/structs beyond the CLI entry point)
- `swift-argument-parser` 1.5.0+ for CLI parsing
