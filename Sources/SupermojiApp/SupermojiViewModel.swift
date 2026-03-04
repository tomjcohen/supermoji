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
