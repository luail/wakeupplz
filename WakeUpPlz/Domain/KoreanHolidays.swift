import Foundation
import Synchronization
// Bundled 2026–2027 data (docs/holiday-data.md) is the fallback; HolidayService replaces whole
// years with downloaded data so new years and later-announced holidays arrive without an app update.
enum KoreanHolidays {
    private static let downloadedYears = Mutex<[Int: [String: String]]>([:])
    static func setDownloaded(_ years: [Int: [String: String]]) { downloadedYears.withLock { $0 = years } }
    static func name(for key: String) -> String? {
        guard let year = Int(key.prefix(4)) else { return nil }
        if let downloaded = downloadedYears.withLock({ $0[year] }) { return downloaded[key] }
        return days[key]
    }
    static var coveredYears: Set<Int> { downloadedYears.withLock { Set($0.keys) }.union(2026...2027) }
    static let days: [String: String] = [
        "2026-01-01":"신정", "2026-02-16":"설날 연휴", "2026-02-17":"설날", "2026-02-18":"설날 연휴",
        "2026-03-01":"삼일절", "2026-03-02":"대체공휴일", "2026-05-01":"노동절", "2026-05-05":"어린이날",
        "2026-05-24":"부처님오신날", "2026-05-25":"대체공휴일", "2026-06-03":"지방선거", "2026-06-06":"현충일",
        "2026-07-17":"제헌절", "2026-08-15":"광복절", "2026-08-17":"대체공휴일",
        "2026-09-24":"추석 연휴", "2026-09-25":"추석", "2026-09-26":"추석 연휴",
        "2026-10-03":"개천절", "2026-10-05":"대체공휴일", "2026-10-09":"한글날", "2026-12-25":"성탄절",
        "2027-01-01":"신정", "2027-02-06":"설날 연휴", "2027-02-07":"설날", "2027-02-08":"설날 연휴", "2027-02-09":"대체공휴일",
        "2027-03-01":"삼일절", "2027-05-01":"노동절", "2027-05-03":"대체공휴일", "2027-05-05":"어린이날", "2027-05-13":"부처님오신날",
        "2027-06-06":"현충일", "2027-07-17":"제헌절", "2027-07-19":"대체공휴일", "2027-08-15":"광복절", "2027-08-16":"대체공휴일",
        "2027-09-14":"추석 연휴", "2027-09-15":"추석", "2027-09-16":"추석 연휴", "2027-10-03":"개천절", "2027-10-04":"대체공휴일",
        "2027-10-09":"한글날", "2027-10-11":"대체공휴일", "2027-12-25":"성탄절", "2027-12-27":"대체공휴일"
    ]
}
