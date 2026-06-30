# supermoji

Swift CLI that generates animated or static GIFs from emoji, using Apple Color Emoji.

## Build & Test

```bash
swift build          # build
swift test           # run all tests
swift run supermoji 😀😃😄              # animate (default): frame-swap GIF, 256px/500ms
swift run supermoji fade ⚪ 🔵          # cross-fade ping-pong loop, 128px (Slack-tuned)
swift run supermoji still 🔴            # single emoji → static GIF, 128px
```

## Subcommands

- `animate` (default) — N mixed emoji/image inputs → frame-swap GIF. Default subcommand, so a bare `supermoji 😀😃😄` still routes here. `--size 256`, `--delay 500`.
- `fade <A> <B>` — cross-fade between exactly two emoji and back, as a seamless looping GIF. `--curve {linear,ease-in,ease-out,ease-in-out}` (default ease-in-out), `--fps 20`, `--duration 0.6` (one-way seconds), `--size 128`, `--supersample 3`.
- `still <A>` — render one emoji as a static GIF via the same renderer as `fade`, so stills and fades render at a uniform size as Slack custom emoji. `--size 128`, `--supersample 3`.

The fade is rendered and composited at a high internal working resolution (`max(size, 160) × supersample`, where 160 is Apple Color Emoji's native strike) and only the final frames are downscaled to `--size` — so the cross-dissolve and edges stay smooth. Raise `--supersample` for more anti-aliasing at the cost of render time.

`fade` and `still` share `renderEmojiFrame` and default to 128px; both warn (stderr) if the output exceeds Slack's 128 KB custom-emoji limit.

## Architecture

Three SPM targets plus an Xcode-built Mac app:

**SupermojiKit** (library) — shared core logic:
- `Sources/SupermojiKit/EmojiSplitter.swift` — `splitEmoji(_:)` splits input string into grapheme clusters.
- `Sources/SupermojiKit/EmojiRenderer.swift` — `renderEmoji(_:size:)` renders one emoji to a CGImage via CoreText/AppKit.
- `Sources/SupermojiKit/GIFWriter.swift` — `writeGIF(frames:delayMs:to:)` assembles CGImages into a GIF via ImageIO.
- `Sources/SupermojiKit/FrameSource.swift` — `FrameSource` struct (`.emoji`/`.image`) and `renderFrame(_:size:)` dispatcher.
- `Sources/SupermojiKit/ImageLoader.swift` — `loadImage(from:size:)` loads and scales image files via ImageIO.
- `Sources/SupermojiKit/EasingCurve.swift` — `EasingCurve` enum (linear/ease-in/ease-out/ease-in-out) with `apply(_:)`.
- `Sources/SupermojiKit/Fade.swift` — `renderEmojiFrame(_:size:supersample:)` (shared supersampled renderer), `blend(_:_:t:)` (premultiplied-alpha cross-dissolve), `fadeTSchedule(forwardFrames:)` (ping-pong t schedule), `makeFadeFrames(from:to:curve:fps:duration:size:)` orchestrator.

**supermoji** (CLI executable) — `Sources/Supermoji/Supermoji.swift`. ArgumentParser entry point with `animate` (default), `fade`, and `still` subcommands. Depends on SupermojiKit.

**SupermojiApp** (SwiftUI Mac app) — built via Xcode project (`project.yml` + xcodegen), not SPM:
- `Sources/SupermojiApp/SupermojiApp.swift` — app entry point.
- `Sources/SupermojiApp/ContentView.swift` — main UI (sequence strip for emoji + images, preview, controls, save).
- `Sources/SupermojiApp/SupermojiViewModel.swift` — rendering, animation, and save logic. Uses `[FrameSource]` for mixed sequences.

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
