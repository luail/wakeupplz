import Foundation

/// Downloads this year's and next year's Korean public holidays from an open dataset built from
/// the government special-day API (no key, no server of ours). Cached on device; the bundled
/// table stays the fallback whenever a download fails or looks wrong.
@MainActor final class HolidayService {
    static let shared = HolidayService()
    private let file = URL.applicationSupportDirectory.appending(path: "WakeUpPlz/holidays.json")
    private struct Cache: Codable { var fetchedAt: Date; var years: [Int: [String: String]] }
    private var cache: Cache?
    var lastUpdated: Date? { cache?.fetchedAt }

    init() {
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(Cache.self, from: data) {
            cache = saved
            KoreanHolidays.setDownloaded(saved.years)
        }
    }
    /// Returns true when the holiday table changed, so schedules can be rebuilt.
    func refreshIfNeeded(now: Date = .now) async -> Bool {
        if let fetchedAt = cache?.fetchedAt, now.timeIntervalSince(fetchedAt) < 7 * 24 * 3600 { return false }
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        var years = cache?.years ?? [:]
        var fetchedAny = false
        for y in [year, year + 1] {
            if let days = await fetch(y) { years[y] = days; fetchedAny = true }
        }
        guard fetchedAny else { return false }
        let changed = years != cache?.years
        cache = Cache(fetchedAt: now, years: years)
        KoreanHolidays.setDownloaded(years)
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        return changed
    }
    private func fetch(_ year: Int) async -> [String: String]? {
        guard let url = URL(string: "https://holidays.hyunbin.page/\(year).json"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else { return nil }
        // Sanity check before trusting it over the bundled table: a full year, dated in that year.
        guard (10...40).contains(raw.count), raw.keys.allSatisfy({ $0.hasPrefix("\(year)-") }) else { return nil }
        return raw.mapValues { $0.joined(separator: ", ") }
    }
}
