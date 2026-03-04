# Supermoji Mac App — Design

## Goal

A simple, modern macOS app that lets non-technical users generate animated GIFs from emoji. Distributed as a notarised DMG via GitHub Releases.

## Architecture

The existing Swift package is restructured into three targets:

- **SupermojiKit** (library) — shared core extracted from the current source files: `EmojiSplitter`, `EmojiRenderer`, `GIFWriter`.
- **supermoji** (executable) — existing CLI, depends on SupermojiKit + ArgumentParser.
- **SupermojiApp** (executable) — new SwiftUI app, depends on SupermojiKit.

A thin Xcode project wraps the SPM package to produce a signed `.app` bundle with Info.plist, entitlements, and asset catalogue. All code remains in the Swift package.

## UI

Single non-resizable window (~360x480pt), three vertical zones:

1. **Emoji input** — text field at top. Placeholder: "Type emoji here...".
2. **Preview** — centre. Animated GIF preview cycling through frames in real-time. Subtle empty state when no emoji entered.
3. **Controls + Save** — bottom strip:
   - Size picker (segmented: 128 / 256 / 512px)
   - Speed picker (segmented: Fast / Medium / Slow)
   - Save button → NSSavePanel

## App Icon

🤩 (star-struck face) rendered at 1024px via the existing `renderEmoji` pipeline, exported as `.icns` for the Xcode asset catalogue.

## Data Flow

```
TextField input
  → splitEmoji() → [String]
  → renderEmoji() for each → [CGImage]
  → Preview: cycle through CGImages on a timer
  → Save: writeGIF(frames:delayMs:to:) → .gif file
```

Rendering runs on a background task. A view model holds `@Published` frames that the preview observes. Changing size or speed triggers a re-render.

## Distribution

- DMG with notarisation, hosted on GitHub Releases.
- Code signing via Xcode project / `xcodebuild`.
- No App Store, no Homebrew cask.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI framework | SwiftUI | Modern, minimal boilerplate, macOS 13+ is sufficient |
| Package structure | Shared library + two executables | Reuses core logic, keeps CLI working |
| Build system | SPM + thin Xcode wrapper | SPM for code, Xcode for app bundle/signing only |
| Settings | Inline (size, speed) | Simple enough to show in main UI, no preferences pane |
| Distribution | Notarised DMG | Simplest path, no App Store review |
