import Foundation

struct Recipient: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var phone: String
    /// Only selected recipients receive the unverified message; others stay saved for later.
    var selected = true
    init(id: UUID = UUID(), name: String, phone: String, selected: Bool = true) {
        self.id = id; self.name = name; self.phone = phone; self.selected = selected
    }
    // Files saved before selection existed have no `selected` key; treat those as selected.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        phone = try c.decode(String.self, forKey: .phone)
        selected = try c.decodeIfPresent(Bool.self, forKey: .selected) ?? true
    }
    static func normalized(_ input: String) -> String {
        var value = input.filter { $0.isASCII && $0.isNumber }
        if input.hasPrefix("+") { value = "+" + value }
        if value.hasPrefix("+82") { value = "0" + value.dropFirst(3) }
        return value
    }
}
struct DayOff: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var start: String
    var end: String
    var title: String
}
struct Routine: Codable, Equatable, Sendable {
    var alarmMinute = 8 * 60 + 20
    var phrase = "일어났어!"
    var message = "아직 기상 인증을 하지 않았어요. WakeUpPlz에서 확인 부탁드려요."
    var recipients: [Recipient] = []
    var activeRecipients: [Recipient] { recipients.filter(\.selected) }
    var excludeWeekends = true
    var excludeHolidays = true
    var daysOff: [DayOff] = []
    var appearance = "system"
    var sound = "Morning Bell.wav"
    var alarmEnabled = false
    // Scheduling notifications is separate from proving that Shortcuts sends messages.
    var messageRemindersEnabled = false
    var verifiedDays: Set<String> = []
    var claimedSlots: Set<String> = []
    // Always 10 minutes after the alarm; older saved files' messageMinute key is ignored on decode.
    static let messageDelay = 10
    var messageMinute: Int { alarmMinute + Self.messageDelay }
    var validationError: String? {
        if !(0..<1440).contains(alarmMinute) { return "알람 시각을 확인해주세요." }
        if messageMinute > 1437 { return "알람은 오후 11:47 이전이어야 해요. 문자가 알람 10분 뒤에 3회 발송돼요." }
        if phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phrase.count > 80 { return "인증 문구는 1~80자로 입력해주세요." }
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "문자 내용을 입력해주세요." }
        return nil
    }
}
struct MessageSlot: Identifiable, Equatable, Sendable {
    var id: String
    var date: Date
    var ordinal: Int
}
struct RoutineEngine: Sendable {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }
    func dayKey(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    func day(_ key: String) -> Date {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return .distantPast }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? .distantPast
    }
    func time(_ minute: Int, on date: Date) -> Date {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date)!
    }
    func reasonOff(_ date: Date, _ routine: Routine) -> String? {
        let key = dayKey(date)
        if let off = routine.daysOff.first(where: { $0.start <= key && key <= $0.end }) { return off.title }
        if routine.excludeHolidays, let name = KoreanHolidays.days[key] { return name }
        if routine.excludeWeekends, calendar.isDateInWeekend(date) { return "주말" }
        return nil
    }
    func holidayCoverage(_ date: Date) -> Bool {
        (2026...2027).contains(calendar.component(.year, from: date))
    }
    func shouldContinueAlarm(on date: Date, routine: Routine, now: Date) -> Bool {
        routine.alarmEnabled && routine.validationError == nil && dayKey(date) == dayKey(now)
            && !routine.verifiedDays.contains(dayKey(now)) && reasonOff(now, routine) == nil
    }
    func alarmDates(_ routine: Routine, now: Date, days: Int = 7) -> [Date] {
        guard routine.validationError == nil else { return [] }
        return (0..<days).compactMap { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let alarm = time(routine.alarmMinute, on: date)
            guard alarm > now, reasonOff(date, routine) == nil, !routine.verifiedDays.contains(dayKey(date)) else { return nil }
            return alarm
        }
    }
    /// Pre-scheduled re-rings every `interval` seconds for 12 minutes after the alarm. Some ways
    /// of silencing an alarm (side button, in-app dismiss) never run the stop intent, so
    /// re-ringing cannot rely on it. Only the next `workdays` days are covered to keep the count
    /// near 100; verification, the stop intent and message requests all reschedule. Unlike
    /// alarmDates, today's backups stay wanted after the main alarm time has passed.
    func backupAlarmDates(_ routine: Routine, now: Date, workdays: Int = 2, interval: Int = 15) -> [(index: Int, date: Date)] {
        guard routine.validationError == nil else { return [] }
        var result: [(index: Int, date: Date)] = []
        var covered = 0
        for offset in 0..<14 where covered < workdays {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            guard reasonOff(date, routine) == nil, !routine.verifiedDays.contains(dayKey(date)) else { continue }
            let alarm = time(routine.alarmMinute, on: date)
            let day = (1...(12 * 60 / interval)).compactMap { k -> (index: Int, date: Date)? in
                let at = alarm.addingTimeInterval(TimeInterval(k * interval))
                return at > now && dayKey(at) == dayKey(date) ? (k, at) : nil
            }
            if !day.isEmpty { result += day; covered += 1 }
        }
        return result
    }
    func slots(_ routine: Routine, on date: Date) -> [MessageSlot] {
        guard routine.validationError == nil, reasonOff(date, routine) == nil,
              !routine.verifiedDays.contains(dayKey(date)),
              !routine.excludeHolidays || holidayCoverage(date) else { return [] }
        return (0..<3).map { n in MessageSlot(id: "\(dayKey(date))-\(n)", date: time(routine.messageMinute + n, on: date), ordinal: n + 1) }
    }
    func dueSlot(_ routine: Routine, now: Date) -> MessageSlot? {
        slots(routine, on: now).first { slot in
            let age = now.timeIntervalSince(slot.date)
            return age >= 0 && age < 60 && !routine.claimedSlots.contains(slot.id)
        }
    }
    func verify(_ input: String, routine: inout Routine, now: Date) -> Bool {
        guard input == routine.phrase, routine.validationError == nil else { return false }
        routine.verifiedDays.insert(dayKey(now))
        return true
    }
    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}
