import Testing
@testable import SupermojiKit

@Test func scheduleHasPingPongLength() {
    // Total frames for a forward+back loop = 2N - 2 (endpoints not duplicated).
    #expect(fadeTSchedule(forwardFrames: 3).count == 4)
    #expect(fadeTSchedule(forwardFrames: 4).count == 6)
    #expect(fadeTSchedule(forwardFrames: 12).count == 22)
}

@Test func scheduleStartsAtZeroAndTurnsAtOne() {
    let schedule = fadeTSchedule(forwardFrames: 4)
    #expect(schedule.first == 0)
    // The forward half (first N frames) ends at the t=1 turnaround.
    #expect(abs(schedule[3] - 1) < 1e-9)
}

@Test func scheduleHasExpectedValuesForThreeFrames() {
    // Forward 0, 0.5, 1 then reverse back through 0.5 (0 and 1 not repeated).
    let schedule = fadeTSchedule(forwardFrames: 3)
    let expected = [0.0, 0.5, 1.0, 0.5]
    #expect(schedule.count == expected.count)
    for (got, want) in zip(schedule, expected) {
        #expect(abs(got - want) < 1e-9)
    }
}

@Test func scheduleIsSymmetricPingPong() {
    let n = 4
    let schedule = fadeTSchedule(forwardFrames: n)
    // Mirror around the turnaround index N-1.
    for k in 1..<(n - 1) {
        #expect(abs(schedule[(n - 1) + k] - schedule[(n - 1) - k]) < 1e-9)
    }
}

@Test func scheduleHasNoConsecutiveDuplicates() {
    let schedule = fadeTSchedule(forwardFrames: 12)
    for i in 1..<schedule.count {
        #expect(schedule[i] != schedule[i - 1])
    }
}
