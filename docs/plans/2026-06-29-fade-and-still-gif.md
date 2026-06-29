# Fade & Still GIF generation

**Date:** 2026-06-29
**Status:** Design approved, pending spec review

## Goal

Add two new CLI capabilities to supermoji, both oriented around **Slack custom emoji**:

1. **`fade`** — cross-fade between two emoji and back again (a seamless ping-pong loop), output as an animated GIF.
2. **`still`** — render a single emoji as a static GIF, using the *same* high-fidelity renderer as `fade`.

The unifying requirement: a static emoji GIF and an animated fade GIF must be the **same class of artefact** — identical pixel dimensions and identical per-emoji rendering — so they render at a uniform size when used together as Slack custom emoji. (Slack's mobile client renders native unicode emoji and custom GIF emoji at different sizes; making *everything* a same-sized custom GIF avoids the mismatch.)

This enables sets like traffic lights (🔴 🟡 🟢 as stills) or progress stages where pending/done steps are stills and the in-progress step is an animating fade — all the same size in a Slack message.

## Background — current behaviour (confirmed)

The existing CLI (`Sources/Supermoji/Supermoji.swift`) takes N mixed emoji/image inputs and produces a frame-swap GIF. A **single input already produces a static GIF**: `effectiveDelay = frames.count == 1 ? 0 : delay`, and `writeGIF` sets `isAnimated = frameCount > 1`, so one frame → non-looping still. Verified empirically: `supermoji ⚪ --size 128 -o still.gif` writes a `GIF version 87a`, 128×128, single frame.

**Gap:** that single-input path renders via `renderEmoji(_:size:)` *directly at output size*. The new `fade` path renders endpoints **supersampled then downscaled**. Left unaddressed, a static `🔵` and the `🔵` endpoint of a fade would differ in pixels/crispness. The fix is a single shared renderer used by both new commands.

## CLI surface

Refactor the current root behaviour into an **`animate` subcommand** and register it as the **default subcommand**, so existing invocations are unchanged:

- `supermoji ⚪🔵😎 --size 256` → routes to `animate`, byte-identical output to today.
- `animate` keeps its current options (`inputs`, `--size` default 256, `--delay` default 500, `--output`) and its current renderer. **Not modified beyond the move.**

Two new subcommands share a fidelity pipeline and Slack-tuned defaults:

### `fade`

```
supermoji fade <A> <B> [--curve ease-in-out] [--fps 20] [--duration 0.6] [--size 128] [-o output.gif]
```

- **Exactly two emoji.** Accepts `fade ⚪ 🔵` (two args) or `fade ⚪🔵` (one arg, two graphemes): inputs are concatenated, split via `splitEmoji`, and the result must be exactly two grapheme clusters. Error otherwise.
- Emoji-only for v1 — image files are rejected (non-goal below).
- `--curve` ∈ `{linear, ease-in, ease-out, ease-in-out}`, default `ease-in-out`.
- `--fps` default 20. `--duration` default 0.6 (one-way fade time, seconds). `--size` default 128 (square). `-o/--output` default `output.gif`.

### `still`

```
supermoji still <A> [--size 128] [-o output.gif]
```

- **Exactly one emoji** (one grapheme cluster after split). Error otherwise.
- `--size` default 128. `-o/--output` default `output.gif`.
- Produces a single-frame (non-looping) GIF via the shared renderer + existing `writeGIF`.

### Shared CLI behaviour (`fade` and `still`)

- **macOS guard.** Both commands check platform and emit a clear error if not on macOS. Implementation: a `#if !os(macOS)` branch in the command body that throws a descriptive error (the error path references no AppKit symbols, so it compiles on non-macOS even though the kit itself is macOS-only). On macOS the normal path runs.
- **Slack size warning.** After writing, if the output file exceeds **128 KB** (Slack's custom-emoji limit), print a warning to stderr suggesting lower `--fps`/`--duration`/`--size`. Non-fatal.

## Animation model (`fade`)

- One-way frame count `N = max(2, round(duration × fps))`.
- Forward parameter `tᵢ = i / (N − 1)` for `i = 0 … N−1` (t=0 → pure A, t=1 → pure B).
- **Ping-pong loop:** forward frames `[0 … N−1]` followed by reverse frames `[N−2 … 1]`. Total **2N − 2** frames. The endpoints (i=0 and i=N−1) appear once per cycle, so there is no duplicated frame at the turnaround and no jump at the loop seam.
- Every frame shares delay `round(1000 / fps)` ms. GIF loops forever (`kCGImagePropertyGIFLoopCount = 0`).
- **Easing shapes the blend amount, not the frame timing.** Frames are evenly spaced in time (constant fps); the eased value `e = curve(tᵢ)` drives the cross-dissolve, so ease-in-out makes the fade linger on each emoji and move briskly through the middle.
- Defaults → N=12, **22 frames @ 50 ms ≈ 1.1 s** per full loop.

### Easing curves

Applied to the linear `t` before blending. All map [0,1]→[0,1], monotonic, with `f(0)=0`, `f(1)=1`:

| Curve | Function |
|-------|----------|
| `linear` | `t` |
| `ease-in` | `t²` |
| `ease-out` | `1 − (1 − t)²` |
| `ease-in-out` | `3t² − 2t³` (smoothstep) |

## Rendering & cross-fade (SupermojiKit)

### Shared endpoint renderer

`renderEmojiFrame(_ emoji: String, size: Int, supersample: Int = 2) throws -> CGImage`

- Render the emoji via the existing CoreText/AppKit path at `size × supersample` pixels, then high-quality downscale (`.high` interpolation) to `size × size`, returning an RGBA8 premultiplied-last CGImage.
- Note: Apple Color Emoji is a bitmap face (native strike ≈160 px), so supersampling primarily improves edge anti-aliasing rather than adding glyph detail. It is kept because it gives crisper, more consistent edges at small Slack sizes, and — critically — guarantees `fade` endpoints and `still` outputs are produced by the identical code path.
- Used by **both** `fade` (for its two endpoints) and `still` (its single frame).

### Cross-fade blend

`blend(_ a: CGImage, _ b: CGImage, t: Double) throws -> CGImage`

- Both inputs are assumed to be the same dimensions and RGBA8 premultiplied-last (guaranteed by `renderEmojiFrame`).
- Per pixel, per channel: `out = round(A·(1 − t) + B·t)`, computed in **premultiplied-alpha space**. This is a correct cross-dissolve including the alpha channel, so the midpoint stays transparent where neither source covers and opaque where either does — important on Slack's varied light/dark backgrounds.
- `t` here is the already-eased value.

### Frame schedule

`fadeTSchedule(forwardFrames N: Int) -> [Double]` → the ping-pong sequence of **linear** t values (length 2N−2). Easing is applied per-frame at blend time, not baked into the schedule, keeping the schedule pure and easily testable.

### Orchestrator

`makeFadeFrames(from a: String, to b: String, curve: EasingCurve, fps: Int, duration: Double, size: Int) throws -> [CGImage]`

- Computes `N`, renders A and B once each via `renderEmojiFrame`, builds the t-schedule, and blends one frame per scheduled t (applying `curve.apply`).
- Returns the full `[CGImage]` loop, handed to the existing `writeGIF(frames:delayMs:to:)`.

### New SupermojiKit API summary

- `enum EasingCurve { case linear, easeIn, easeOut, easeInOut; func apply(_ t: Double) -> Double }`
- `func renderEmojiFrame(_:size:supersample:) throws -> CGImage`
- `func blend(_:_:t:) throws -> CGImage`
- `func fadeTSchedule(forwardFrames:) -> [Double]`
- `func makeFadeFrames(from:to:curve:fps:duration:size:) throws -> [CGImage]`

`writeGIF` is reused unchanged for both still (1 frame) and fade (2N−2 frames).

## Testing (Swift Testing)

- **Easing:** for each curve, `apply(0) == 0`, `apply(1) == 1`, and monotonic non-decreasing across samples.
- **Schedule:** `fadeTSchedule(forwardFrames: N)` has length `2N−2`, starts at 0, its forward half ends at 1, contains no consecutive duplicates, and is symmetric (ping-pong).
- **Blend:** on small synthetic images (e.g. solid red vs solid blue, and a transparent-vs-opaque pair) — `t=0` ⇒ equals A, `t=1` ⇒ equals B, `t=0.5` ⇒ midpoint channel *and* alpha values within rounding tolerance.
- **Consistency guarantee:** the `🔵` produced by `renderEmojiFrame("🔵", size: 128)` is byte-identical to the `t=1` endpoint frame of `makeFadeFrames(from: "⚪", to: "🔵", …, size: 128)` — i.e. `still` and `fade` share pixels.
- **Requested integration case:** `fade ⚪ 🔵 --size 128` → assert frame count = `2N−2`, first frame ≈ white-circle render, last forward frame (`t=1`) ≈ blue-circle render, a mid frame differs from both endpoints, and the written GIF is a valid non-empty animated GIF.
- **Still integration:** `still 🔴 --size 128` → single-frame 128×128 GIF, non-looping.

## Non-goals (v1)

- Image-file inputs in `fade`/`still` (emoji-only).
- More than two inputs to `fade`.
- Per-direction or asymmetric curves (one curve applies to both directions of the ping-pong).
- Changing `animate`'s behaviour or fidelity (it is only relocated to a subcommand for back-compat).
- Mac app (`SupermojiApp`) changes — out of scope; this is CLI + kit only.

## Files touched

- `Sources/SupermojiKit/EasingCurve.swift` *(new)*
- `Sources/SupermojiKit/Fade.swift` *(new — `renderEmojiFrame`, `blend`, `fadeTSchedule`, `makeFadeFrames`)*
- `Sources/Supermoji/Supermoji.swift` *(refactor root → `animate` default subcommand; add `Fade`, `Still` subcommands)*
- `Tests/SupermojiTests/…` *(new tests per above)*
- `CLAUDE.md` *(document new subcommands + files)*
