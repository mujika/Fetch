import SwiftUI
import UIKit

struct WheelScrubberView: View {
    let duration: Double
    @Binding var currentTime: Double
    let secondsPerTurn: Double
    let onSeek: (Double) -> Void

    @State private var gestureStartTime: Double?
    @State private var lastHapticTickIndex: Int = 0
    @State private var currentGestureRadians: Double = 0

    init(duration: Double, currentTime: Binding<Double>, secondsPerTurn: Double = 12.0, onSeek: @escaping (Double) -> Void) {
        self.duration = duration
        self._currentTime = currentTime
        self.secondsPerTurn = secondsPerTurn
        self.onSeek = onSeek
    }

    private var quarterTurnRadians: Double { .pi / 2.0 }

    private func hapticIfNeeded(for angle: Double) {
        let ticks = Int(floor(abs(angle) / quarterTurnRadians))
        if ticks > lastHapticTickIndex {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            lastHapticTickIndex = ticks
        }
    }

    private func knobPosition(size: CGFloat, angle: Double) -> CGPoint {
        let radius = (size / 2.0) - 12.0
        let x = (size / 2.0) + CGFloat(cos(angle)) * radius
        let y = (size / 2.0) + CGFloat(sin(angle)) * radius
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 16)

                let pos = knobPosition(size: size, angle: currentGestureRadians)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .position(x: pos.x, y: pos.y)
                    .shadow(radius: 2)

                VStack(spacing: 4) {
                    Text(timeString(currentTime))
                        .font(.title2.monospacedDigit())
                    Text("/ " + timeString(duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(rotationGesture())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scrubber")
            .accessibilityValue(timeString(currentTime))
            .accessibilityAdjustableAction { direction in
                var delta: Double = 0
                switch direction {
                case .increment:
                    delta = 1
                case .decrement:
                    delta = -1
                default:
                    delta = 0
                }
                if delta != 0 {
                    let target = WheelScrubberMath.clampTime(current: currentTime, delta: delta, duration: duration)
                    currentTime = target
                    onSeek(target)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func rotationGesture() -> some Gesture {
        RotationGesture()
            .onChanged { value in
                if gestureStartTime == nil {
                    gestureStartTime = currentTime
                    lastHapticTickIndex = 0
                }
                let angle = value.radians
                currentGestureRadians = angle
                hapticIfNeeded(for: angle)
                let deltaSeconds = WheelScrubberMath.angleToDeltaSecondsConsideringDeadZone(angle, secondsPerTurn: secondsPerTurn)
                let startTime = gestureStartTime ?? currentTime
                let target = WheelScrubberMath.clampTime(current: startTime, delta: deltaSeconds, duration: duration)
                onSeek(target)
            }
            .onEnded { value in
                let angle = value.radians
                let deltaSeconds = WheelScrubberMath.angleToDeltaSecondsConsideringDeadZone(angle, secondsPerTurn: secondsPerTurn)
                let startTime = gestureStartTime ?? currentTime
                let target = WheelScrubberMath.clampTime(current: startTime, delta: deltaSeconds, duration: duration)
                currentTime = target
                onSeek(target)
                gestureStartTime = nil
                currentGestureRadians = 0
                lastHapticTickIndex = 0
            }
    }

    private func timeString(_ t: Double) -> String {
        if t.isNaN || !t.isFinite { return "00:00" }
        let total = max(0, Int(t.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
