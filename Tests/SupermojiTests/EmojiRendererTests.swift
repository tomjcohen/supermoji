import Testing
import CoreGraphics
@testable import supermoji

@Test func rendersSingleEmojiToImage() throws {
    let image = try renderEmoji("😀", size: 64)
    #expect(image.width == 64)
    #expect(image.height == 64)
}

@Test func rendersAtRequestedSize() throws {
    let image = try renderEmoji("🎉", size: 128)
    #expect(image.width == 128)
    #expect(image.height == 128)
}

@Test func renderedImageHasColorData() throws {
    let image = try renderEmoji("😀", size: 64)
    guard let dataProvider = image.dataProvider, let data = dataProvider.data else {
        Issue.record("No image data")
        return
    }
    let bytes = CFDataGetLength(data)
    // A 64x64 RGBA image should have 64*64*4 = 16384 bytes
    #expect(bytes == 64 * 64 * 4)
}
