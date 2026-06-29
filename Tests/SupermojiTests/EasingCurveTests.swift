import Testing
@testable import SupermojiKit

private let curves: [EasingCurve] = [.linear, .easeIn, .easeOut, .easeInOut]

@Test func easingCurvesPinEndpoints() {
    for curve in curves {
        #expect(abs(curve.apply(0) - 0) < 1e-9, "\(curve) should map 0→0")
        #expect(abs(curve.apply(1) - 1) < 1e-9, "\(curve) should map 1→1")
    }
}

@Test func easingCurvesAreMonotonic() {
    for curve in curves {
        var previous = curve.apply(0)
        for step in 1...100 {
            let value = curve.apply(Double(step) / 100)
            #expect(value >= previous - 1e-12, "\(curve) should be non-decreasing")
            previous = value
        }
    }
}

@Test func easingCurvesHaveExpectedMidpoints() {
    #expect(abs(EasingCurve.linear.apply(0.5) - 0.5) < 1e-9)
    #expect(abs(EasingCurve.easeIn.apply(0.5) - 0.25) < 1e-9)
    #expect(abs(EasingCurve.easeOut.apply(0.5) - 0.75) < 1e-9)
    #expect(abs(EasingCurve.easeInOut.apply(0.5) - 0.5) < 1e-9)
}
