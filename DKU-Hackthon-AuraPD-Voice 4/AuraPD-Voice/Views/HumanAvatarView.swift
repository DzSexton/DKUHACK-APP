import SwiftUI

/// A Canvas-drawn human figure whose limbs shake in real time driven by
/// accelerometer data.  Distal parts (hands) displace more than the trunk,
/// matching the characteristic resting-tremor pattern of Parkinson's disease.
///
/// When not capturing live data, a synthetic 5 Hz sinusoid is applied based
/// on the last assessed motor state (tremor → large; OFF → subtle; ON → none).
struct HumanAvatarView: View {

    /// Real-time offset from accelerometer (zero when not capturing).
    let tremorOffset: CGSize
    let state: MotorState
    let isCapturing: Bool
    /// When true the caller owns the animation loop and passes the offset directly.
    /// The internal `syntheticOffset` TimelineView is skipped entirely.
    /// Use this from TimelinePlaybackView so the avatar obeys the three-mode state machine.
    var useExternalOffset: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if isCapturing || useExternalOffset {
                    // Caller supplies the offset — either live accelerometer or
                    // pre-computed historical / zero value from the parent TimelineView.
                    avatarFigure(offset: tremorOffset)
                } else {
                    // Dashboard idle path: synthetic state-based animation at ~30 fps.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                        avatarFigure(offset: syntheticOffset(at: tl.date))
                    }
                }
            }

            if isCapturing {
                RecordingBadge()
                    .padding(6)
            }
        }
    }

    // MARK: – Synthetic tremor

    private func syntheticOffset(at date: Date) -> CGSize {
        let t = date.timeIntervalSinceReferenceDate
        let amplitude: Double
        switch state {
        case .tremor:  amplitude = 5.5    // PD resting tremor ~4–6 Hz
        case .off:     amplitude = 1.5
        default:       amplitude = 0.0
        }
        // Two slightly detuned frequencies give a realistic Lissajous-like path.
        return CGSize(
            width:  sin(t * .pi * 2 * 5.0) * amplitude,
            height: cos(t * .pi * 2 * 4.7) * amplitude * 0.45
        )
    }

    // MARK: – Canvas figure

    private func avatarFigure(offset: CGSize) -> some View {
        Canvas { context, size in
            let cx = size.width  / 2
            let cy = size.height / 2

            // ── Differential shake per segment ──────────────────────────────
            // Trunk barely moves; hands shake ~3× more (distal tremor pattern).
            let trunkOff = CGPoint(x: offset.width * 0.25, y: offset.height * 0.25)
            let elbowOff = CGPoint(x: offset.width * 0.65, y: offset.height * 0.65)
            let handOff  = CGPoint(x: offset.width * 1.00, y: offset.height * 1.00)
            let headOff  = CGPoint(x: offset.width * 0.45, y: offset.height * 0.45)

            // Helper: absolute canvas point
            func p(_ x: CGFloat, _ y: CGFloat,
                   _ d: CGPoint = .zero) -> CGPoint {
                CGPoint(x: cx + x + d.x, y: cy + y + d.y)
            }

            let accentColor  = stateColor
            let fillShading  = GraphicsContext.Shading.color(accentColor.opacity(0.88))
            let strokeShading = GraphicsContext.Shading.color(accentColor)
            let limbStyle    = StrokeStyle(lineWidth: 11, lineCap: .round,
                                           lineJoin: .round)

            // ── Capture glow ─────────────────────────────────────────────────
            if isCapturing {
                let glowRect = CGRect(x: cx - 72 + trunkOff.x,
                                     y: cy - 118 + trunkOff.y,
                                     width: 144, height: 228)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(accentColor.opacity(0.10))
                )
            }

            // ── Head ─────────────────────────────────────────────────────────
            let headC = p(0, -90, headOff)
            context.fill(
                Path(ellipseIn: CGRect(x: headC.x - 21, y: headC.y - 21,
                                       width: 42, height: 42)),
                with: fillShading
            )

            // ── Torso ────────────────────────────────────────────────────────
            context.fill(
                Path(roundedRect: CGRect(x: cx - 17 + trunkOff.x,
                                          y: cy - 64 + trunkOff.y,
                                          width: 34, height: 68),
                     cornerRadius: 9),
                with: fillShading
            )

            // ── Left arm ─────────────────────────────────────────────────────
            var lArm = Path()
            lArm.move(to:    p(-15, -52, trunkOff))
            lArm.addLine(to: p(-43, -20, elbowOff))
            lArm.addLine(to: p(-47,  12, handOff))
            context.stroke(lArm, with: strokeShading, style: limbStyle)

            let lHand = p(-47, 12, handOff)
            context.fill(
                Path(ellipseIn: CGRect(x: lHand.x - 9, y: lHand.y - 9,
                                       width: 18, height: 18)),
                with: fillShading
            )

            // ── Right arm (both hands shake the same direction — device moves as one)
            var rArm = Path()
            rArm.move(to:    p(15, -52, trunkOff))
            rArm.addLine(to: p(43, -20, elbowOff))
            rArm.addLine(to: p(47,  12, handOff))
            context.stroke(rArm, with: strokeShading, style: limbStyle)

            let rHand = p(47, 12, handOff)
            context.fill(
                Path(ellipseIn: CGRect(x: rHand.x - 9, y: rHand.y - 9,
                                       width: 18, height: 18)),
                with: fillShading
            )

            // ── Left leg ──────────────────────────────────────────────────────
            var lLeg = Path()
            lLeg.move(to:    p(-9,  4, trunkOff))
            lLeg.addLine(to: p(-18, 50, trunkOff))
            lLeg.addLine(to: p(-23, 88, trunkOff))
            context.stroke(lLeg, with: strokeShading, style: limbStyle)

            // ── Right leg ─────────────────────────────────────────────────────
            var rLeg = Path()
            rLeg.move(to:    p( 9,  4, trunkOff))
            rLeg.addLine(to: p(18, 50, trunkOff))
            rLeg.addLine(to: p(23, 88, trunkOff))
            context.stroke(rLeg, with: strokeShading, style: limbStyle)
        }
        .frame(width: 160, height: 270)
    }

    // MARK: – Helpers

    private var stateColor: Color {
        switch state {
        case .on:      return .green
        case .off:     return .orange
        case .tremor:  return .red
        case .unknown: return .purple
        }
    }
}

// MARK: – Recording badge

private struct RecordingBadge: View {
    @State private var visible = true

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .opacity(visible ? 1 : 0.15)
                .animation(
                    .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                    value: visible
                )
            Text("REC")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear { visible = false }
    }
}

#Preview {
    VStack(spacing: 24) {
        HumanAvatarView(tremorOffset: .zero,      state: .on,      isCapturing: false)
        HumanAvatarView(tremorOffset: CGSize(width: 4, height: 2), state: .tremor, isCapturing: true)
        HumanAvatarView(tremorOffset: .zero,      state: .off,     isCapturing: false)
    }
    .padding()
}
