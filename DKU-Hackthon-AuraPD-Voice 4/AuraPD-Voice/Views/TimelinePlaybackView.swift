import SwiftUI

struct TimelinePlaybackView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    // MARK: - State

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    /// Slider progress: 0.0 = 00:00, 1.0 = 24:00
    @State private var sliderProgress: Double = Self.nowProgress()
    @State private var isUserDragging: Bool = false
    @State private var isPlaying: Bool = false
    /// Unified "current time" for the whole page, refreshed every second by liveTicker
    @State private var now: Date = Date()

    private let liveTicker     = Timer.publish(every: 1.0,  on: .main, in: .common).autoconnect()
    private let playbackTicker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    /// 2-minute snap threshold for live-mode auto-follow
    private let snapThreshold: Double = 2.0 / 1440.0

    // MARK: - Computed properties

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    /// 0–1 progress corresponding to the current moment (derived from `now`)
    private var currentTimeProgress: Double {
        let start = Calendar.current.startOfDay(for: now)
        return now.timeIntervalSince(start) / 86400.0
    }

    /// Today: slider max = current moment. Historical date: max = 24:00 (1.0).
    private var sliderMax: Double { isToday ? currentTimeProgress : 1.0 }

    private var isLiveMode: Bool {
        isToday && !isUserDragging && !isPlaying
            && abs(sliderProgress - currentTimeProgress) <= snapThreshold
    }

    private var displayedIntensity: Double {
        if isLiveMode && appViewModel.isChecking { return appViewModel.liveTremorIntensity }
        return appViewModel.intensity(for: selectedDate, atProgress: sliderProgress)
    }

    private var displayedState: MotorState {
        let i = displayedIntensity
        return i > 0.65 ? .tremor : (i > 0.35 ? .off : .on)
    }

    /// Progress-bar time display: precise to the second (HH:mm:ss)
    private var sliderTimeHMS: String {
        let total = sliderProgress * 86400
        let h = Int(total / 3600)
        let m = Int(total.truncatingRemainder(dividingBy: 3600) / 60)
        let s = Int(total.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// HH:mm time derived from the unified `now` state
    private var nowHHmm: String {
        String(format: "%02d:%02d",
               Calendar.current.component(.hour, from: now),
               Calendar.current.component(.minute, from: now))
    }

    /// HH:mm at the current slider position (no seconds, used in info card)
    private var sliderHHmm: String {
        let total = sliderProgress * 86400
        let h = Int(total / 3600)
        let m = Int(total.truncatingRemainder(dividingBy: 3600) / 60)
        return String(format: "%02d:%02d", h, m)
    }

    private var currentRecord: TremorRecord? {
        appViewModel.record(for: selectedDate, atProgress: sliderProgress)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 6)

                avatarSection

                Spacer(minLength: 6)

                infoRow
                    .padding(.horizontal, 16)

                bottomPanel
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Symptom Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { datePicker }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.indigo.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onReceive(liveTicker)     { _ in handleLiveTick() }
            .onReceive(playbackTicker) { _ in handlePlaybackTick() }
            .onChange(of: selectedDate) { _, date in resetSliderForDate(date) }
        }
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        if isLiveMode && appViewModel.isChecking {
            HStack(spacing: 10) {
                PulseDot(color: .red)
                Text("Live monitoring · Dashboard sync")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.red, in: Capsule())
            }
            .padding(11)
            .background(Color.red.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if isLiveMode {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill").foregroundStyle(.indigo)
                Text("Current time · \(nowHHmm)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("Today").font(.caption.weight(.semibold)).foregroundStyle(.indigo)
            }
            .padding(11)
            .background(Color.indigo.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise.circle.fill").foregroundStyle(.orange)
                Text("Playback · \(formattedSelectedDate) \(sliderHHmm)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isToday {
                    Button("Back to Live") {
                        withAnimation(.spring(response: 0.38)) {
                            sliderProgress = currentTimeProgress
                        }
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.indigo)
                }
            }
            .padding(11)
            .background(Color.orange.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Avatar section

    /// Three-mode intensity state machine:
    ///
    /// | Mode            | Condition                           | Intensity source              |
    /// |-----------------|-------------------------------------|-------------------------------|
    /// | Live sync       | `isLiveMode && isChecking`          | `liveTremorIntensity` (50 Hz) |
    /// | Historical replay | `isUserDragging \|\| isPlaying`   | historical mock record        |
    /// | Static default  | everything else                     | 0.0 → avatar completely still |
    private var avatarIntensity: Double {
        if isLiveMode && appViewModel.isChecking {
            return appViewModel.liveTremorIntensity   // Mode 1 – live Dashboard sync
        }
        if isUserDragging || isPlaying {
            return displayedIntensity                 // Mode 2 – scrubbing replay
        }
        return 0.0                                    // Mode 3 – static default
    }

    private var avatarSection: some View {
        ZStack {
            Circle()
                .fill(stateColor(displayedState).opacity(avatarIntensity * 0.12))
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.5), value: avatarIntensity)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                HumanAvatarView(
                    tremorOffset: computeOffset(intensity: avatarIntensity, at: tl.date),
                    state: displayedState,
                    isCapturing: isLiveMode && appViewModel.isChecking,
                    useExternalOffset: true
                )
            }

            if isLiveMode && appViewModel.isChecking {
                VStack { HStack { Spacer(); LiveRecBadge() }; Spacer() }
                    .frame(width: 180, height: 270)
            }
        }
        .frame(width: 200, height: 270)
        .scaleEffect(0.72)
        .frame(width: 144, height: 194)
    }

    // MARK: - Info row

    private var infoRow: some View {
        HStack(spacing: 0) {
            infoCell(
                value: sliderHHmm,
                label: "Time",
                color: .primary
            )
            Divider().frame(height: 36)
            infoCell(
                value: String(format: "%.0f%%", displayedIntensity * 100),
                label: intensityLabel(displayedIntensity),
                color: intensityColor(displayedIntensity)
            )
            Divider().frame(height: 36)
            HStack(spacing: 4) {
                Image(systemName: displayedState.symbolName).font(.caption)
                VStack(spacing: 1) {
                    Text(displayedState.displayName).font(.subheadline.bold())
                    Text("Motor State").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(stateColor(displayedState))
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: displayedIntensity)
    }

    private func infoCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 6) {
            intensityChart
                .frame(height: 52)

            Text(sliderTimeHMS)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(isLiveMode ? .red : .indigo)
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(nil, value: sliderTimeHMS)

            Slider(
                value: $sliderProgress,
                in: 0...max(sliderMax, 0.0001)
            ) { editing in
                isUserDragging = editing
                if editing  { isPlaying = false }
                if !editing { onSliderReleased() }
            }
            .tint(isLiveMode ? .red : .indigo)

            HStack {
                Text("00:00")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                if isToday {
                    Text("Now \(nowHHmm)")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.indigo)
                }
                Spacer()
                Text(isToday ? nowHHmm : "24:00")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }

            HStack(spacing: 32) {
                Button {
                    isPlaying = false
                    withAnimation(.spring(response: 0.3)) { sliderProgress = 0 }
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Skip to start")

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(isLiveMode ? .red : .indigo)
                        .symbolEffect(.bounce, value: isPlaying)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button {
                    isPlaying = false
                    withAnimation(.spring(response: 0.3)) { sliderProgress = sliderMax }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Skip to end")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    // MARK: - Intensity chart

    @ViewBuilder
    private var intensityChart: some View {
        let dayRecords = appViewModel.records(for: selectedDate)
        if dayRecords.count > 1 {
            let dayStart = Calendar.current.startOfDay(for: selectedDate)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .leading) {
                    ForEach([0.25, 0.5, 0.75], id: \.self) { level in
                        Path { p in
                            let y = h * CGFloat(1 - level)
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    }

                    ForEach([6.0, 12.0, 18.0], id: \.self) { hour in
                        let x = CGFloat(hour / 24.0) * w
                        Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    }

                    Path { path in
                        for (i, r) in dayRecords.enumerated() {
                            let x = CGFloat(r.timestamp.timeIntervalSince(dayStart) / 86400) * w
                            let y = h * CGFloat(1 - r.tremorIntensity)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else       { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        if let last = dayRecords.last {
                            let lx = CGFloat(last.timestamp.timeIntervalSince(dayStart) / 86400) * w
                            path.addLine(to: CGPoint(x: lx, y: h))
                            path.addLine(to: CGPoint(x: 0, y: h))
                            path.closeSubpath()
                        }
                    }
                    .fill(LinearGradient(
                        colors: [Color.indigo.opacity(0.20), .clear],
                        startPoint: .top, endPoint: .bottom
                    ))

                    Path { path in
                        for (i, r) in dayRecords.enumerated() {
                            let x = CGFloat(r.timestamp.timeIntervalSince(dayStart) / 86400) * w
                            let y = h * CGFloat(1 - r.tremorIntensity)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else       { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.indigo.opacity(0.75),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if isToday {
                        let futureX = CGFloat(currentTimeProgress) * w
                        Rectangle()
                            .fill(Color(.systemBackground).opacity(0.55))
                            .frame(width: max(w - futureX, 0))
                            .frame(maxHeight: .infinity)
                            .offset(x: futureX)
                    }

                    if isToday {
                        Rectangle()
                            .fill(Color.indigo.opacity(0.4))
                            .frame(width: 1.5, height: h)
                            .offset(x: CGFloat(currentTimeProgress) * w)
                    }

                    Rectangle()
                        .fill(isLiveMode ? Color.red : Color.indigo)
                        .frame(width: 2, height: h)
                        .offset(x: CGFloat(sliderProgress) * w - 1)
                        .animation(.interactiveSpring(), value: sliderProgress)

                    let dotX = CGFloat(sliderProgress) * w
                    let dotY = h * CGFloat(1 - displayedIntensity)
                    Circle()
                        .fill(isLiveMode ? Color.red : Color.indigo)
                        .frame(width: 9, height: 9)
                        .offset(x: dotX - 4.5, y: dotY - 4.5)
                        .animation(.interactiveSpring(), value: sliderProgress)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
                .overlay(
                    Text("No data for this day")
                        .font(.caption).foregroundStyle(.secondary)
                )
        }
    }

    // MARK: - Toolbar DatePicker

    private var datePicker: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            DatePicker(
                "",
                selection: $selectedDate,
                in: appViewModel.availableDateRange,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(.indigo)
        }
    }

    // MARK: - Event handling

    private func handleLiveTick() {
        now = Date()
        guard isToday, !isUserDragging, !isPlaying else { return }
        let target = currentTimeProgress
        if abs(sliderProgress - target) <= snapThreshold || sliderProgress >= target {
            sliderProgress = target
        }
        if sliderProgress > sliderMax { sliderProgress = sliderMax }
    }

    private func togglePlayback() { isPlaying.toggle() }

    /// Advances playback each 0.5 s. Step = 451 s (7 min 31 s) — not a multiple of 60,
    /// so the seconds digit visibly changes on every step.
    private func handlePlaybackTick() {
        guard isPlaying else { return }
        let step = 451.0 / 86400.0
        let next = sliderProgress + step
        if next >= sliderMax {
            withAnimation(.spring(response: 0.3)) { sliderProgress = sliderMax }
            isPlaying = false
        } else {
            withAnimation(.linear(duration: 0.42)) { sliderProgress = next }
        }
    }

    private func onSliderReleased() {
        if sliderProgress > sliderMax { sliderProgress = sliderMax }
        guard isToday else { return }
        // Snap back to live mode if within 5 minutes of current time
        if abs(sliderProgress - currentTimeProgress) < 5.0 / 1440.0 {
            withAnimation(.spring(response: 0.35)) {
                sliderProgress = currentTimeProgress
            }
        }
    }

    private func resetSliderForDate(_ date: Date) {
        isUserDragging = false
        sliderProgress = Calendar.current.isDateInToday(date) ? currentTimeProgress : 0.5
    }

    // MARK: - Helpers

    /// Computes a sinusoidal tremor offset for `intensity` at the given animation clock tick.
    /// Returns `.zero` when intensity is negligible so the avatar is fully static.
    private func computeOffset(intensity: Double, at date: Date) -> CGSize {
        guard intensity > 0.01 else { return .zero }
        let t   = date.timeIntervalSinceReferenceDate
        let amp = intensity * 8.0
        return CGSize(
            width:  sin(t * .pi * 2 * 5.0) * amp,
            height: cos(t * .pi * 2 * 4.7) * amp * 0.45
        )
    }

    private var formattedSelectedDate: String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        return fmt.string(from: selectedDate)
    }

    private func stateColor(_ s: MotorState) -> Color {
        switch s { case .on: .green; case .off: .orange; case .tremor: .red; case .unknown: .purple }
    }

    private func intensityColor(_ v: Double) -> Color {
        switch v { case ..<0.25: .green; case ..<0.50: .yellow; case ..<0.75: .orange; default: .red }
    }

    private func intensityLabel(_ v: Double) -> String {
        switch v { case ..<0.25: "Minimal"; case ..<0.50: "Mild"; case ..<0.75: "Moderate"; default: "Severe" }
    }

    static func nowProgress() -> Double {
        let now = Date()
        return now.timeIntervalSince(Calendar.current.startOfDay(for: now)) / 86400.0
    }
}

// MARK: - PulseDot

private struct PulseDot: View {
    let color: Color
    @State private var pulsing = false
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25)).frame(width: 16, height: 16)
                .scaleEffect(pulsing ? 1.45 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .onAppear { pulsing = true }
    }
}

// MARK: - LiveRecBadge

private struct LiveRecBadge: View {
    @State private var visible = true
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.red).frame(width: 7, height: 7)
                .opacity(visible ? 1 : 0.15)
                .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: visible)
            Text("REC")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear { visible = false }
    }
}

#Preview {
    TimelinePlaybackView()
        .environmentObject(AppViewModel())
        .environmentObject(MainViewModel())
}
