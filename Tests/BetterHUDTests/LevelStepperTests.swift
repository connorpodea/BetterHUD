import Testing

@testable import BetterHUD

/// Sixteenths are exactly representable in binary floating point, so these
/// compare exactly on purpose: a tolerance would hide the very drift the
/// stepper exists to absorb.
struct LevelStepperTests {
    private static func sixteenths(_ n: Float) -> Float { n / 16 }

    @Test("A clean level moves exactly one step in each direction")
    func stepsFromACleanLevel() {
        let half = Self.sixteenths(8)
        #expect(LevelStepper.step(from: half, increasing: true) == Self.sixteenths(9))
        #expect(LevelStepper.step(from: half, increasing: false) == Self.sixteenths(7))
    }

    /// The regression this whole type exists for.
    ///
    /// After setting 9/16 the device reads the level back as 8.999999/16.
    /// Truncating toward the direction of travel takes that to 8, adds one, and
    /// writes back 9/16 — the level it is already at. The key stops working.
    @Test("A level that reads back just under a step still advances")
    func doesNotStallOnAShortReadback() {
        let justUnderNine: Float = 8.999999 / 16

        #expect(LevelStepper.step(from: justUnderNine, increasing: true) == Self.sixteenths(10))
        #expect(LevelStepper.step(from: justUnderNine, increasing: true) != Self.sixteenths(9))
        #expect(LevelStepper.step(from: justUnderNine, increasing: false) == Self.sixteenths(8))
    }

    @Test("A level that reads back just over a step lands on clean stops too")
    func snapsFromALongReadback() {
        // Brightness is the one that overshoots, reading back around 12.04/16.
        let justOverTwelve: Float = 12.04 / 16

        #expect(LevelStepper.step(from: justOverTwelve, increasing: true) == Self.sixteenths(13))
        #expect(LevelStepper.step(from: justOverTwelve, increasing: false) == Self.sixteenths(11))
    }

    @Test("A level nowhere near a step is snapped before it is moved")
    func snapsBeforeStepping() {
        // 8.5/16 rounds to 9, so one step up is 10 rather than 9.5.
        let betweenSteps = Self.sixteenths(8.5)
        #expect(LevelStepper.step(from: betweenSteps, increasing: true) == Self.sixteenths(10))
    }

    @Test("Stepping repeatedly walks the grid one stop at a time")
    func walksTheGrid() {
        var level = Self.sixteenths(0)
        for expected in 1...16 {
            level = LevelStepper.step(from: level, increasing: true)
            #expect(level == Self.sixteenths(Float(expected)))
        }
    }

    @Test("The result runs past the ends of the range, for callers to clamp")
    func doesNotClamp() {
        // Documenting the contract rather than wishing for a different one: the
        // volume keys read the unclamped result to decide whether the bottom of
        // the range was reached, which is what mutes the output.
        #expect(LevelStepper.step(from: 0, increasing: false) == Self.sixteenths(-1))
        #expect(LevelStepper.step(from: 1, increasing: true) == Self.sixteenths(17))
    }
}
