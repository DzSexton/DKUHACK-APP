import Foundation
import Combine

// MARK: - AppViewModel（全局跨 Tab 状态机）

/// 管理跨标签页联动的全局状态：监测开关、实时震颤幅度、30 天历史数据。
///
/// **数据流转**：
/// Dashboard 触发监测 → `isChecking = true` → Timeline Avatar 同步响应 →
/// Timer 每 3 秒将实时数据追加到今天的历史记录 → 时间轴可回放。
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - 公开的全局状态

    /// 是否正在进行实时监测（Dashboard 触发，Timeline 响应）
    @Published private(set) var isChecking: Bool = false
    /// 当前实时震颤幅度（0.0 ~ 1.0），10Hz 更新，驱动 Timeline Avatar 抖动
    @Published private(set) var liveTremorIntensity: Double = 0.0

    // MARK: - 30 天历史数据

    /// 过去 30 天 + 今天的震颤记录
    /// Key = 当天 00:00:00 的 Date（startOfDay），Value = 当天按时间正序排列的记录数组
    @Published private(set) var historicalData: [Date: [TremorRecord]] = [:]

    // MARK: - Combine 订阅

    private var liveSimCancellable: AnyCancellable?    // 实时震颤模拟（10Hz）
    private var recordingCancellable: AnyCancellable?  // 数据记录（每 3s）

    /// 内部正弦相位，用于平滑的震颤幅度变化
    private var livePhase: Double = 0.0

    // MARK: - 初始化

    init() {
        // 在 init 时预生成 30 天 + 今天的 Mock 数据
        generateMock30DaysData()
    }

    // MARK: - 监测控制

    /// 开始实时监测：启动震颤模拟 + 数据记录定时器
    func startChecking() {
        guard !isChecking else { return }
        isChecking = true
        livePhase = 0.0

        // ① 实时震颤强度模拟（10 Hz，正弦波 + 随机噪声）
        liveSimCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.livePhase += 0.1
                // 缓慢漂移的基线（模拟药效曲线）+ 高频抖动
                let drift  = 0.60 + 0.22 * sin(self.livePhase * 0.35)
                let noise  = Double.random(in: -0.07...0.07)
                self.liveTremorIntensity = max(0.05, min(0.95, drift + noise))
            }

        // ② 每 3 秒将当前幅度写入今天的历史记录
        recordingCancellable = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isChecking else { return }
                self.appendLiveRecord()
            }
    }

    /// 停止实时监测，清空实时状态
    func stopChecking() {
        isChecking = false
        liveTremorIntensity = 0.0
        liveSimCancellable?.cancel()
        liveSimCancellable = nil
        recordingCancellable?.cancel()
        recordingCancellable = nil
    }

    // MARK: - 数据查询接口

    /// 返回指定日期的所有震颤记录（按时间正序）
    func records(for date: Date) -> [TremorRecord] {
        historicalData[Calendar.current.startOfDay(for: date)] ?? []
    }

    /// 根据 Slider 进度（0~1 代表 00:00~24:00）查询最接近的震颤幅度
    func intensity(for date: Date, atProgress progress: Double) -> Double {
        let dayRecords = records(for: date)
        guard !dayRecords.isEmpty else { return 0.0 }
        let dayStart = Calendar.current.startOfDay(for: date)
        let target   = dayStart.addingTimeInterval(progress * 86400)
        return dayRecords
            .min { abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target)) }?
            .tremorIntensity ?? 0.0
    }

    /// 根据 Slider 进度查询最接近的 TremorRecord（用于详情卡显示）
    func record(for date: Date, atProgress progress: Double) -> TremorRecord? {
        let dayRecords = records(for: date)
        guard !dayRecords.isEmpty else { return nil }
        let dayStart = Calendar.current.startOfDay(for: date)
        let target   = dayStart.addingTimeInterval(progress * 86400)
        return dayRecords
            .min { abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target)) }
    }

    /// DatePicker 的可选日期范围：过去 30 天到今天
    var availableDateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today
        return start...Date()
    }

    // MARK: - 私有：追加实时记录

    private func appendLiveRecord() {
        let now   = Date()
        let state: MotorState = liveTremorIntensity > 0.65 ? .tremor
            : (liveTremorIntensity > 0.35 ? .off : .on)
        let record = TremorRecord(
            timestamp: now,
            tremorIntensity: liveTremorIntensity,
            state: state
        )
        let key = Calendar.current.startOfDay(for: now)
        historicalData[key, default: []].append(record)
        historicalData[key]?.sort { $0.timestamp < $1.timestamp }
    }

    // MARK: - 私有：Mock 30 天数据生成

    private func generateMock30DaysData() {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 过去 30 天：生成全天 48 条记录（每 30 分钟一条）
        for offset in 1...30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            historicalData[day] = makeFullDayRecords(startOf: day)
        }

        // 今天：仅生成到当前时刻为止的数据
        historicalData[today] = makeTodayRecords(startOf: today, upTo: Date())
    }

    /// 生成一整天的 Mock 记录（00:00 ~ 24:00，每 30 分钟一条）
    private func makeFullDayRecords(startOf dayStart: Date) -> [TremorRecord] {
        makeRecords(from: dayStart, to: dayStart.addingTimeInterval(86400))
    }

    /// 生成今天从 00:00 到指定时刻的记录
    private func makeTodayRecords(startOf dayStart: Date, upTo cutoff: Date) -> [TremorRecord] {
        makeRecords(from: dayStart, to: cutoff)
    }

    private func makeRecords(from start: Date, to end: Date) -> [TremorRecord] {
        var records: [TremorRecord] = []
        var t = start
        while t < end {
            let hoursFromMidnight = t.timeIntervalSince(
                Calendar.current.startOfDay(for: t)
            ) / 3600.0
            let intensity = pdIntensity(hour: hoursFromMidnight)
            let state: MotorState = intensity > 0.65 ? .tremor : (intensity > 0.35 ? .off : .on)
            records.append(TremorRecord(timestamp: t, tremorIntensity: intensity, state: state))
            t = t.addingTimeInterval(1800) // 30 分钟步长
        }
        return records
    }

    /// 帕金森震颤强度模型（模拟三次服药 + 药效衰退模式）
    ///
    /// 公式 = 基线 + 8h 药效周期 + 三个服药前峰值（高斯脉冲）+ 随机噪声
    private func pdIntensity(hour h: Double) -> Double {
        let baseline     = 0.28
        // 8 小时药效周期（正弦，三次服药）
        let medCycle     = 0.14 * sin(h * .pi / 4.0)
        // 三个服药前 OFF 峰（高斯形状）
        let morningPeak  = 0.38 * exp(-pow(h - 7.5,  2) / 3.0)   // 07:30 服药前
        let noonPeak     = 0.30 * exp(-pow(h - 13.5, 2) / 3.0)   // 13:30 服药前
        let eveningPeak  = 0.24 * exp(-pow(h - 19.0, 2) / 2.5)   // 19:00 服药前
        let noise        = Double.random(in: -0.07...0.07)
        return max(0.05, min(0.95, baseline + medCycle + morningPeak + noonPeak + eveningPeak + noise))
    }
}
