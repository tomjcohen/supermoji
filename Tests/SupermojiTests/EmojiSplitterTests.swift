import Testing
@testable import SupermojiKit

@Test func splitSimpleEmoji() {
    let result = splitEmoji("😀😃😄")
    #expect(result == ["😀", "😃", "😄"])
}

@Test func splitSingleEmoji() {
    let result = splitEmoji("🎉")
    #expect(result == ["🎉"])
}

@Test func splitCompoundEmoji() {
    // Skin tone modifier
    let result = splitEmoji("👍🏽👍🏻")
    #expect(result == ["👍🏽", "👍🏻"])
}

@Test func splitFlagEmoji() {
    let result = splitEmoji("🇬🇧🇺🇸")
    #expect(result == ["🇬🇧", "🇺🇸"])
}

@Test func splitZWJEmoji() {
    // Family emoji (ZWJ sequence)
    let result = splitEmoji("👨‍👩‍👧‍👦")
    #expect(result == ["👨‍👩‍👧‍👦"])
}

@Test func splitEmptyString() {
    let result = splitEmoji("")
    #expect(result == [])
}
