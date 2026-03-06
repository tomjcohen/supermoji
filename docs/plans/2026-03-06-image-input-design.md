# Image Input Feature Design

Allow images (PNG, JPEG, etc.) to be added as frames in the emoji GIF sequence, in both the CLI and Mac app.

## SupermojiKit — FrameSource & ImageLoader

New file `Sources/SupermojiKit/FrameSource.swift`:
- `FrameSource` enum: `.emoji(String)` | `.image(URL)`
- `func renderFrame(_ source: FrameSource, size: Int) throws -> CGImage` — dispatches to `renderEmoji` for `.emoji`, or `loadImage` for `.image`

New file `Sources/SupermojiKit/ImageLoader.swift`:
- `func loadImage(from url: URL, size: Int) throws -> CGImage` — loads via `CGImageSource`, scales to fit `size x size` square (aspect-fit, centred on transparent background)
- Supports PNG, JPEG, TIFF, HEIC — anything `CGImageSource` can read

Existing `renderEmoji`, `splitEmoji`, `writeGIF` unchanged.

## CLI — Mixed Arguments

`Sources/Supermoji/Supermoji.swift`:
- Replace `@Argument var emoji: String` with `@Argument var inputs: [String]`
- New `func parseInputs(_ inputs: [String]) -> [FrameSource]`: if file exists at path, `.image(URL)`; otherwise split as emoji via `splitEmoji`
- Help text: `"Emoji characters and/or image file paths to include as frames"`

Example: `supermoji "hello" logo.png "world" --size 256 --delay 500 -o output.gif`

`parseInputs` lives in the CLI target (Mac app doesn't need string-based parsing).

## Mac App UI — Sequence Builder

**ViewModel:**
- Replace `@Published var emojiText: String` with `@Published var items: [FrameSource]`
- `render()` iterates over `items`, calling `renderFrame` for each
- Downstream (cgFrames, frames, animation, save, copy) unchanged — already work with `[CGImage]`

**ContentView — sequence strip replacing the text field:**

```
+--------------------------------------+
|  [A] [B] [img] [C]  [+ Add]         |  <- scrollable strip
+--------------------------------------+
|         (animated preview)           |
+--------------------------------------+
|  Size:  [128] [256] [512]            |
|  Speed: [Fast] [Medium] [Slow]       |
+--------------------------------------+
|     [Copy]          [Save GIF]       |
+--------------------------------------+
```

- Horizontal `ScrollView` of item thumbnails (emoji as text, images as thumbnail)
- Each item has an X button for deletion
- Reorderable via drag-and-drop (`.draggable`/`.dropDestination`, macOS 14+)
- Emoji input: text field that appends emoji as individual `.emoji` items on return
- Image input: "+" button opens `NSOpenPanel` file picker; also supports drag-and-drop onto strip

## Testing

SupermojiKit:
- `loadImage` — loads a known PNG fixture, returns CGImage at requested size
- `renderFrame` with `.emoji` — same result as `renderEmoji`
- `renderFrame` with `.image` — returns correctly sized CGImage
- `loadImage` with invalid path — throws error

CLI:
- `parseInputs` with mixed emoji and file paths — correct `[FrameSource]` sequence

Test fixture: small PNG under `Tests/SupermojiKitTests/Fixtures/`.
