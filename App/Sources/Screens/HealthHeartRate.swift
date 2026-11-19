import Foundation
import HealthKit

/// Reads his average heart rate over the warm-up from Apple Health (since 2.0).
/// Asks for read permission once, only when a cardio warm-up ends. The simulator, UI tests (-uitest)
/// and a device without Health skip it entirely and return nil — never a crash.
enum HealthHeartRate {
    static var available: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return false }
        return HKHealthStore.isHealthDataAvailable()
        #endif
    }

    /// The words under the heart-rate field while Health has nothing yet.
    static let waiting = "Heart rate comes from Apple Health when your Garmin syncs."

    /// Average beats per minute between the two moments, or nil when Health has no samples (yet).
    static func average(from start: Date, to end: Date) async -> Int? {
        guard available, end > start, let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let store = HKHealthStore()
        // Asked once; Apple remembers the answer and does not show the sheet again.
        do { try await store.requestAuthorization(toShare: [], read: [type]) } catch { return nil }
        return await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .discreteAverage) { _, stats, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats?.averageQuantity()?.doubleValue(for: unit)
                cont.resume(returning: bpm.map { Int($0.rounded()) })
            }
            store.execute(query)
        }
    }
}
