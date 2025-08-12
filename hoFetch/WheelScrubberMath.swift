import Foundation

enum WheelScrubberMath {
    static let deadZoneRadians: Double = .pi / 30.0

    static func angleToDeltaSeconds(_ deltaAngleRadians: Double, secondsPerTurn: Double) -> Double {
        (deltaAngleRadians / (2.0 * .pi)) * secondsPerTurn
    }

    static func angleToDeltaSecondsConsideringDeadZone(_ deltaAngleRadians: Double, secondsPerTurn: Double, deadZone: Double = WheelScrubberMath.deadZoneRadians) -> Double {
        let absAngle = abs(deltaAngleRadians)
        if absAngle < deadZone { return 0.0 }
        return angleToDeltaSeconds(deltaAngleRadians, secondsPerTurn: secondsPerTurn)
    }

    static func clampTime(current: Double, delta: Double, duration: Double) -> Double {
        let target = current + delta
        if target < 0 { return 0 }
        if target > duration { return duration }
        return target
    }
}
