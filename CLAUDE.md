# supermoji

Swift CLI that generates animated or static GIFs from emoji, using Apple Color Emoji.

## Build & Test

```bash
swift build          # build
swift test           # run all tests
swift run supermoji 😀😃😄  # run with defaults (256px, 500ms, output.gif)
```

## Architecture

Three SPM targets plus an Xcode-built Mac app:

**SupermojiKit** (library) — shared core logic:
- `Sources/SupermojiKit/EmojiSplitter.swift` — `splitEmoji(_:)` splits input string into grapheme clusters.
- `Sources/SupermojiKit/EmojiRenderer.swift` — `renderEmoji(_:size:)` renders one emoji to a CGImage via CoreText/AppKit.
- `Sources/SupermojiKit/GIFWriter.swift` — `writeGIF(frames:delayMs:to:)` assembles CGImages into a GIF via ImageIO.

**supermoji** (CLI executable) — `Sources/Supermoji/Supermoji.swift`. ArgumentParser entry point, depends on SupermojiKit.

**SupermojiApp** (SwiftUI Mac app) — built via Xcode project (`project.yml` + xcodegen), not SPM:
- `Sources/SupermojiApp/SupermojiApp.swift` — app entry point.
- `Sources/SupermojiApp/ContentView.swift` — main UI (emoji input, preview, controls, save).
- `Sources/SupermojiApp/SupermojiViewModel.swift` — rendering, animation, and save logic.

SupermojiKit targets macOS 13+. The Mac app requires macOS 14 (SwiftUI APIs).

## Git Conventions

- Use conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`
- PR titles also use conventional commit format (e.g. `docs: restore plans`)
- Always work in a git worktree (`.worktrees/`) for feature branches — never work directly on main

## Key Conventions

- macOS-only (depends on AppKit for colour emoji rendering)
- Swift 6 with strict concurrency — uses `@preconcurrency import AppKit` for NSFont/NSAttributedString
- Tests use Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- All functions are free functions (no classes/structs beyond the CLI entry point)
- `swift-argument-parser` 1.5.0+ for CLI parsing

## Releases

- Version derived from latest git tag (e.g. `v1.1.0`), no VERSION file
- Release workflow: `.github/workflows/release.yml`
- Triggered by `release-patch`, `release-minor`, or `release-major` labels on merged PRs
- Builds DMG via xcodegen + xcodebuild, creates GitHub Release with DMG attached
