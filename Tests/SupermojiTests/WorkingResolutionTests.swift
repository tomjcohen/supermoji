import Testing
@testable import SupermojiKit

@Test func workingResolutionSupersamplesOutput() {
    #expect(workingResolution(for: 128, supersample: 3) == 480)
    #expect(workingResolution(for: 256, supersample: 2) == 512)
}

@Test func workingResolutionFloorsToNativeStrike() {
    // Tiny outputs still render from the full 160px native strike.
    #expect(workingResolution(for: 32, supersample: 2) == 320)  // max(32,160)*2
    #expect(workingResolution(for: 200, supersample: 1) == 200) // already past native
}

@Test func workingResolutionClampsSupersampleToAtLeastOne() {
    #expect(workingResolution(for: 128, supersample: 0) == 160) // max(128,160)*1
}
