# supermoji — Design

A Swift CLI that renders Apple Color Emoji into animated (or static) GIFs.

## Usage

```
supermoji 😀😃😄😁😆              # animated GIF, 256px, 500ms delay → output.gif
supermoji 🤙👍 --size 512         # larger
supermoji 🤙👍 --delay 200        # faster
supermoji 🤙👍 -o thumbs.gif     # custom output path
supermoji 🎉                      # single emoji → static GIF
```

## Arguments & Flags

| Arg/Flag | Required | Default | Description |
|----------|----------|---------|-------------|
| emoji (positional) | Yes | — | One or more emoji characters as a single string |
| `--size` | No | 256 | Pixel dimension (square) |
| `--delay` | No | 500 | Frame delay in milliseconds |
| `-o, --output` | No | `output.gif` | Output file path |

## Architecture

Single-file Swift CLI (`main.swift`), built as a Swift Package with no external dependencies beyond `swift-argument-parser`.

1. **Parse args** — Swift ArgumentParser for the CLI interface
2. **Split emoji** — iterate Unicode scalars, respecting grapheme clusters (handles compound emoji like flags, skin tones)
3. **Render frames** — for each emoji, create a CGContext, draw via NSAttributedString with the system emoji font at the requested size
4. **Assemble GIF** — CGImageDestination with kCGImagePropertyGIFDictionary for frame delays and loop count. Single emoji = single frame, no animation delay.
5. **Write to disk**

## Approach: CoreText + CoreGraphics + ImageIO

Render each emoji character using NSAttributedString drawn into a CGContext, then assemble frames into an animated GIF using CGImageDestination (ImageIO framework).

Pure Apple frameworks for rendering. AppKit is used for NSAttributedString emoji rendering (required for colour bitmap emoji from the sbix font). macOS-only, which is fine since we depend on Apple Color Emoji.

## Dependencies

- `swift-argument-parser` — Apple's official CLI argument parsing library
- AppKit, CoreGraphics, ImageIO (system frameworks)
