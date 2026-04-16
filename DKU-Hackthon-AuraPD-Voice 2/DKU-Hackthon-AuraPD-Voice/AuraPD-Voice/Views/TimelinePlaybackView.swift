import SwiftUI

/// 症状时间轴视图（单屏版）
///
/// - 整页无滚动，所有内容固定在一屏内
/// - 进度条旁的时间精确到秒（HH:mm:ss）；其他地方精确到分钟
/// - 全页"当前时间"统一由 `now` 状态驱动，每秒刷新一次，保证一致性
/// - 今日模式下，滑块上限 = 当前时刻，无法拖到尚未发生的时间
struct TimelinePlaybackView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    // MARK: - 状态

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    /// 滑块进度（0.0 = 00:00 ↔ 1.0 = 24:00）
    @State private var sliderProgress: Double = Self.nowProgress()
    @State private var isUserDragging: Bool = false
    /// 是否正在自动回放
    @State private var isPlaying: Bool = false
    /// ★ 全页统一的"当前时刻"，每秒由 liveTicker 更新一次，确保所有时间显示一致
    @State private var now: Date = Date()

    private let liveTicker    = Timer.publish(every: 1.0,  on: .main, in: .common).autoconnect()
    /// 回放推进器：每 0.5 秒前进一步（每步 = 30 分钟 Mock 数据间隔）
    private let playbackTicker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    /// 2 分钟的进度阈值，用于 Live 吸附判断
    private let snapThreshold: Double = 2.0 / 1440.0

    // MARK: - 计算属性

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    /// 当前时刻对应的 0~1 进度（从 `now` 派生，保证与页面时间一致）
    private var currentTimeProgress: Double {
        let start = Calendar.current.startOfDay(for: now)
        return now.timeIntervalSince(start) / 86400.0
    }

    /// 今日模式：滑块上限 = 当前时刻；历史日期：上限 = 24:00（1.0）
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

    /// ★ 进度条显示时间：精确到秒（HH:mm:ss）
    private var sliderTimeHMS: String {
        let total = sliderProgress * 86400
        let h = Int(total / 3600)
        let m = Int(total.truncatingRemainder(dividingBy: 3600) / 60)
        let s = Int(total.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// 其他地方的时间：精确到分钟（HH:mm），从统一的 `now` 派生
    private var nowHHmm: String {
        String(format: "%02d:%02d",
               Calendar.current.component(.hour, from: now),
               Calendar.current.component(.minute, from: now))
    }

    /// 滑块位置的 HH:mm（不含秒，用于信息卡）
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
            // ★ 外层 VStack，无 ScrollView，严格单屏
            VStack(spacing: 0) {

                // ① 状态横幅
                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 6)

                // ② Avatar 动画区
                avatarSection

                Spacer(minLength: 6)

                // ③ 当前时刻信息卡（始终显示，无数据时显示占位）
                infoRow
                    .padding(.horizontal, 16)

                // ④ 折线图 + 进度条（固定底部区域）
                bottomPanel
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            .navigationTitle("症状时间轴")
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

    // MARK: - ① 状态横幅

    @ViewBuilder
    private var statusBanner: some View {
        if isLiveMode && appViewModel.isChecking {
            HStack(spacing: 10) {
                PulseDot(color: .red)
                Text("实时监测中 · Dashboard 同步")
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
                Text("当前时刻 · \(nowHHmm)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("今日").font(.caption.weight(.semibold)).foregroundStyle(.indigo)
            }
            .padding(11)
            .background(Color.indigo.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise.circle.fill").foregroundStyle(.orange)
                Text("历史回放 · \(formattedSelectedDate) \(sliderHHmm)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if isToday {
                    Button("返回实时") {
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

    // MARK: - ② Avatar 动画区

    private var avatarSection: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(stateColor(displayedState).opacity(displayedIntensity * 0.12))
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 0.5), value: displayedState)

            // 30fps 连续动画，振幅由 displayedIntensity 实时决定
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                HumanAvatarView(
                    tremorOffset: tremorOffset(intensity: displayedIntensity, at: tl.date),
                    state: displayedState,
                    isCapturing: isLiveMode && appViewModel.isChecking
                )
            }

            if isLiveMode && appViewModel.isChecking {
                VStack { HStack { Spacer(); LiveRecBadge() }; Spacer() }
                    .frame(width: 180, height: 270)
            }
        }
        // ★ 缩放整个 ZStack 适配单屏高度，保持比例
        .frame(width: 200, height: 270)
        .scaleEffect(0.72)
        .frame(width: 144, height: 194)  // 布局尺寸 = 原始 × 0.72
    }

    // MARK: - ③ 信息行

    private var infoRow: some View {
        HStack(spacing: 0) {
            infoCell(
                value: sliderHHmm,
                label: "时间点",
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
                    Text("运动状态").font(.caption2).foregroundStyle(.secondary)
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

    // MARK: - ④ 底部面板：折线图 + 进度条

    private var bottomPanel: some View {
        VStack(spacing: 6) {
            // 折线图（时间轴坐标系，X=00:00~24:00）
            intensityChart
                .frame(height: 52)

            // ★ 进度条中央显示精确时间（HH:mm:ss）
            Text(sliderTimeHMS)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(isLiveMode ? .red : .indigo)
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(nil, value: sliderTimeHMS)  // 禁用文字动画，避免抖动

            // 主滑块
            // ★ in: 0...sliderMax 确保今日不能拖到当前时刻之后
            Slider(
                value: $sliderProgress,
                in: 0...max(sliderMax, 0.0001)
            ) { editing in
                isUserDragging = editing
                if editing  { isPlaying = false }   // 拖动时停止自动播放
                if !editing { onSliderReleased() }
            }
            .tint(isLiveMode ? .red : .indigo)

            // 时间轴标签行
            HStack {
                Text("00:00")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                if isToday {
                    Text("现在 \(nowHHmm)")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.indigo)
                }
                Spacer()
                Text(isToday ? nowHHmm : "24:00")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }

            // ── 播放控制按钮行 ──────────────────────────────────────
            HStack(spacing: 32) {
                // 跳到最前
                Button {
                    isPlaying = false
                    withAnimation(.spring(response: 0.3)) { sliderProgress = 0 }
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("跳到开始")

                // 播放 / 暂停
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(isLiveMode ? .red : .indigo)
                        .symbolEffect(.bounce, value: isPlaying)
                }
                .accessibilityLabel(isPlaying ? "暂停" : "播放")

                // 跳到最末（今日：当前时刻；历史：24:00）
                Button {
                    isPlaying = false
                    withAnimation(.spring(response: 0.3)) { sliderProgress = sliderMax }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("跳到结尾")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    // MARK: - 折线图

    @ViewBuilder
    private var intensityChart: some View {
        let dayRecords = appViewModel.records(for: selectedDate)
        if dayRecords.count > 1 {
            let dayStart = Calendar.current.startOfDay(for: selectedDate)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .leading) {
                    // 水平参考线
                    ForEach([0.25, 0.5, 0.75], id: \.self) { level in
                        Path { p in
                            let y = h * CGFloat(1 - level)
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    }

                    // 时刻标记线（6h / 12h / 18h）
                    ForEach([6.0, 12.0, 18.0], id: \.self) { hour in
                        let x = CGFloat(hour / 24.0) * w
                        Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    }

                    // 渐变填充
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

                    // 折线
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

                    // ★ 今日：未来区域灰色遮罩（数据不存在的部分）
                    if isToday {
                        let futureX = CGFloat(currentTimeProgress) * w
                        Rectangle()
                            .fill(Color(.systemBackground).opacity(0.55))
                            .frame(width: max(w - futureX, 0))
                            .frame(maxHeight: .infinity)
                            .offset(x: futureX)
                    }

                    // 当前时刻参考线（今日）
                    if isToday {
                        Rectangle()
                            .fill(Color.indigo.opacity(0.4))
                            .frame(width: 1.5, height: h)
                            .offset(x: CGFloat(currentTimeProgress) * w)
                    }

                    // 滑块位置指示竖线
                    Rectangle()
                        .fill(isLiveMode ? Color.red : Color.indigo)
                        .frame(width: 2, height: h)
                        .offset(x: CGFloat(sliderProgress) * w - 1)
                        .animation(.interactiveSpring(), value: sliderProgress)

                    // 滑块位置小圆点
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
            // 无数据占位
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
                .overlay(
                    Text("当日暂无数据")
                        .font(.caption).foregroundStyle(.secondary)
                )
        }
    }

    // MARK: - 工具栏 DatePicker

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

    // MARK: - 事件处理

    private func handleLiveTick() {
        // ★ 每秒更新统一的"当前时间"，驱动全页所有时间显示
        now = Date()

        guard isToday, !isUserDragging, !isPlaying else { return }
        let target = currentTimeProgress
        // 贴近当前时刻则自动跟随
        if abs(sliderProgress - target) <= snapThreshold || sliderProgress >= target {
            sliderProgress = target
        }
        // 防止 sliderProgress 超出今日上限
        if sliderProgress > sliderMax {
            sliderProgress = sliderMax
        }
    }

    /// 播放 / 暂停切换（纯切换，不重置位置）
    private func togglePlayback() {
        isPlaying.toggle()
    }

    /// 回放推进（每 0.5 秒由 playbackTicker 调用）
    ///
    /// 步长 = 451 秒（7分31秒），不是 60 的倍数，
    /// 确保 HH:mm:ss 中的秒数每一步都有变化，视觉上可见"走秒"。
    private func handlePlaybackTick() {
        guard isPlaying else { return }
        let step = 451.0 / 86400.0   // ≈ 7 分 31 秒 / 步，秒数每步不同
        let next = sliderProgress + step
        if next >= sliderMax {
            withAnimation(.spring(response: 0.3)) { sliderProgress = sliderMax }
            isPlaying = false
        } else {
            withAnimation(.linear(duration: 0.42)) { sliderProgress = next }
        }
    }

    private func onSliderReleased() {
        // 释放时将超出上限的进度夹回 sliderMax
        if sliderProgress > sliderMax {
            sliderProgress = sliderMax
        }
        guard isToday else { return }
        // 距离当前时刻 ≤ 5 分钟则自动吸附回 Live 模式
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

    // MARK: - 辅助

    private func tremorOffset(intensity: Double, at date: Date) -> CGSize {
        let t = date.timeIntervalSinceReferenceDate
        let amp = intensity * 8.0
        return CGSize(
            width:  sin(t * .pi * 2 * 5.0) * amp,
            height: cos(t * .pi * 2 * 4.7) * amp * 0.45
        )
    }

    private var formattedSelectedDate: String {
        let fmt = DateFormatter(); fmt.dateFormat = "M月d日"
        return fmt.string(from: selectedDate)
    }

    private func stateColor(_ s: MotorState) -> Color {
        switch s { case .on: .green; case .off: .orange; case .tremor: .red; case .unknown: .purple }
    }

    private func intensityColor(_ v: Double) -> Color {
        switch v { case ..<0.25: .green; case ..<0.50: .yellow; case ..<0.75: .orange; default: .red }
    }

    private func intensityLabel(_ v: Double) -> String {
        switch v { case ..<0.25: "轻微震颤"; case ..<0.50: "轻度震颤"; case ..<0.75: "中度震颤"; default: "重度震颤" }
    }

    static func nowProgress() -> Double {
        let now = Date()
        return now.timeIntervalSince(Calendar.current.startOfDay(for: now)) / 86400.0
    }
}

// MARK: - 脉冲指示点

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

// MARK: - Live REC 徽章

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
