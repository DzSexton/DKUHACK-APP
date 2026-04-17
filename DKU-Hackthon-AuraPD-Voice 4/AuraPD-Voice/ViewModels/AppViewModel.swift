import Foundation
import Combine

// MARK: - AppViewModel (global cross-tab state machine)

/// Manages global state shared across tabs: monitoring toggle, live tremor amplitude,
/// and 30-day historical data.
///
/// **Data flow**: Dashboard triggers monitoring → `isChecking = true` → Timeline Avatar
/// syncs → Timer appends live data to today's history every 3 s → Timeline can replay.
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published global state

    /// Whether real-time monitoring is active (Dashboard triggers, Timeline responds)
    @Published private(set) var isChecking: Bool = false
    /// Current live tremor amplitude (0.0–1.0), updated at 50 Hz, drives Timeline Avatar shake
    @Published var liveTremorIntensity: Double = 0.0

    // MARK: - 30-day historical data

    /// Tremor records for the past 30 days plus today.
    /// Key = start-of-day Date (00:00:00); Value = records for that day in chronological order.
    @Published private(set) var historicalData: [Date: [TremorRecord]] = [:]

    // MARK: - Combine subscriptions

    private var recordingCancellable: AnyCancellable?

    // MARK: - Initialisation

    init() {
        generateMock30DaysData()
    }

    // MARK: - Monitoring control

    /// Starts real-time monitoring: launches the 3-second data-recording timer.
    func startChecking() {
        guard !isChecking else { return }
        isChecking = true

        recordingCancellable = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isChecking else { return }
                self.appendLiveRecord()
            }
    }

    /// Stops real-time monitoring and clears live state.
    func stopChecking() {
        isChecking = false
        liveTremorIntensity = 0.0
        recordingCancellable?.cancel()
        recordingCancellable = nil
    }

    // MARK: - Data query interface

    /// Returns all tremor records for the given date (chronological order).
    func records(for date: Date) -> [TremorRecord] {
        historicalData[Calendar.current.startOfDay(for: date)] ?? []
    }

    /// Returns the tremor intensity closest to `progress` (0=00:00, 1=24:00) for the given date.
    func intensity(for date: Date, atProgress progress: Double) -> Double {
        let dayRecords = records(for: date)
        guard !dayRecords.isEmpty else { return 0.0 }
        let dayStart = Calendar.current.startOfDay(for: date)
        let target   = dayStart.addingTimeInterval(progress * 86400)
        return dayRecords
            .min { abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target)) }?
            .tremorIntensity ?? 0.0
    }

    /// Returns the TremorRecord closest to `progress` for detail-card display.
    func record(for date: Date, atProgress progress: Double) -> TremorRecord? {
        let dayRecords = records(for: date)
        guard !dayRecords.isEmpty else { return nil }
        let dayStart = Calendar.current.startOfDay(for: date)
        let target   = dayStart.addingTimeInterval(progress * 86400)
        return dayRecords
            .min { abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target)) }
    }

    /// Selectable date range for the DatePicker: past 30 days through today.
    var availableDateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today
        return start...Date()
    }

    // MARK: - Private: append live record

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

    // MARK: - Private: mock 30-day data generation

    private func generateMock30DaysData() {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Past 30 days: 48 records per day (every 30 minutes)
        for offset in 1...30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            historicalData[day] = makeFullDayRecords(startOf: day)
        }

        // Today: generate records only up to the current moment
        historicalData[today] = makeTodayRecords(startOf: today, upTo: Date())
    }

    /// Generates a full day of mock records (00:00–24:00, every 30 minutes)
    private func makeFullDayRecords(startOf dayStart: Date) -> [TremorRecord] {
        makeRecords(from: dayStart, to: dayStart.addingTimeInterval(86400))
    }

    /// Generates records from 00:00 today up to `cutoff`
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
            t = t.addingTimeInterval(1800) // 30-minute step
        }
        return records
    }

    /// Parkinson's tremor intensity model (simulates three-dose medication + wearing-off pattern).
    ///
    /// Formula: baseline + 8h medication cycle + three pre-dose Gaussian peaks + random noise
    private func pdIntensity(hour h: Double) -> Double {
        let baseline     = 0.28
        let medCycle     = 0.14 * sin(h * .pi / 4.0)          // 8h medication cycle (sinusoidal)
        let morningPeak  = 0.38 * exp(-pow(h - 7.5,  2) / 3.0)   // pre-morning-dose peak ~07:30
        let noonPeak     = 0.30 * exp(-pow(h - 13.5, 2) / 3.0)   // pre-noon-dose peak ~13:30
        let eveningPeak  = 0.24 * exp(-pow(h - 19.0, 2) / 2.5)   // pre-evening-dose peak ~19:00
        let noise        = Double.random(in: -0.07...0.07)
        return max(0.05, min(0.95, baseline + medCycle + morningPeak + noonPeak + eveningPeak + noise))
    }
}
