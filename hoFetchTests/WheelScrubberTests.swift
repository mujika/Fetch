import Foundation
import Testing
@testable import hoFetch

struct WheelScrubberTests {

    @Test func angleToSeconds_basic() async throws {
        let spt: Double = 12.0
        #expect(WheelScrubberMath.angleToDeltaSeconds(0, secondsPerTurn: spt) == 0)
        let quarter = Double.pi / 2.0
        let half = Double.pi
        let full = 2.0 * Double.pi
        let eps = 1e-9

        let q = WheelScrubberMath.angleToDeltaSeconds(quarter, secondsPerTurn: spt)
        #expect(abs(q - spt * 0.25) < eps)

        let h = WheelScrubberMath.angleToDeltaSeconds(half, secondsPerTurn: spt)
        #expect(abs(h - spt * 0.5) < eps)

        let f = WheelScrubberMath.angleToDeltaSeconds(full, secondsPerTurn: spt)
        #expect(abs(f - spt * 1.0) < eps)

        let neg = WheelScrubberMath.angleToDeltaSeconds(-half, secondsPerTurn: spt)
        #expect(abs(neg - (-spt * 0.5)) < eps)
    }

    @Test func deadZone_behavior() async throws {
        let spt: Double = 12.0
        let dz = WheelScrubberMath.deadZoneRadians

        let justBelow = dz * 0.99
        let below = WheelScrubberMath.angleToDeltaSecondsConsideringDeadZone(justBelow, secondsPerTurn: spt, deadZone: dz)
        #expect(below == 0)

        let justAbove = dz * 1.01
        let above = WheelScrubberMath.angleToDeltaSecondsConsideringDeadZone(justAbove, secondsPerTurn: spt, deadZone: dz)
        #expect(above != 0)
    }

    @Test func clamp_behavior() async throws {
        let duration: Double = 100
        let cur: Double = 50

        let t1 = WheelScrubberMath.clampTime(current: cur, delta: -60, duration: duration)
        #expect(t1 == 0)

        let t2 = WheelScrubberMath.clampTime(current: cur, delta: 10, duration: duration)
        #expect(t2 == 60)

        let t3 = WheelScrubberMath.clampTime(current: cur, delta: 100, duration: duration)
        #expect(t3 == duration)
    }
}
