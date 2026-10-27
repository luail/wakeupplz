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
/// A one-off alarm on one date, such as a nap. Verified on its own; days off don't apply.
struct ExtraAlarm: Codable, Equatable, Sendable {
    var day: String
    var minute: Int
    var id: String { day + "+" + String(format: "%02d%02d", minute / 60, minute % 60) }
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
    /// Weekend or holiday dates the user works on: alarm and messages run as on a workday.
    var workDays: Set<String> = []
    var appearance = "system"
    var sound = "Morning Bell.wav"
    var alarmEnabled = false
    // Scheduling notifications is separate from proving that Shortcuts sends messages.
    var messageRemindersEnabled = false
    var verifiedDays: Set<String> = []
    var claimedSlots: Set<String> = []
    var extraAlarms: [ExtraAlarm] = []
    var verifiedExtras: Set<String> = []
    init() {}
    // Missing keys fall back to defaults, so adding a setting never breaks a saved file.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T { try c.decodeIfPresent(T.self, forKey: key) ?? fallback }
        let d = Routine()
        alarmMinute = try value(.alarmMinute, d.alarmMinute)
        phrase = try value(.phrase, d.phrase)
        message = try value(.message, d.message)
        recipients = try value(.recipients, d.recipients)
        excludeWeekends = try value(.excludeWeekends, d.excludeWeekends)
        excludeHolidays = try value(.excludeHolidays, d.excludeHolidays)
        daysOff = try value(.daysOff, d.daysOff)
        workDays = try value(.workDays, d.workDays)
        appearance = try value(.appearance, d.appearance)
        sound = try value(.sound, d.sound)
        alarmEnabled = try value(.alarmEnabled, d.alarmEnabled)
        messageRemindersEnabled = try value(.messageRemindersEnabled, d.messageRemindersEnabled)
        verifiedDays = try value(.verifiedDays, d.verifiedDays)
        claimedSlots = try value(.claimedSlots, d.claimedSlots)
        extraAlarms = try value(.extraAlarms, d.extraAlarms)
        verifiedExtras = try value(.verifiedExtras, d.verifiedExtras)
    }
    // Always 10 minutes after the alarm; older saved files' messageMinute key is ignored on decode.
    static let messageDelay = 10
    var messageMinute: Int { alarmMinute + Self.messageDelay }
    var validationError: String? {
        if !(0..<1440).contains(alarmMinute) { return "알람 시각을 확인해주세요." }
        if messageMinute > 1437 { return "알람은 오후 11:47 이전이어야 해요. 문자가 알람 10분 뒤에 3회 발송돼요." }
        if extraAlarms.contains(where: { !(0...1427).contains($0.minute) }) { return "추가 알람은 오후 11:47 이전이어야 해요." }
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
        if routine.workDays.contains(key) { return nil }
        if routine.excludeHolidays, let name = KoreanHolidays.name(for: key) { return name }
        if routine.excludeWeekends, calendar.isDateInWeekend(date) { return "주말" }
        return nil
    }
    func holidayCoverage(_ date: Date) -> Bool {
        KoreanHolidays.coveredYears.contains(calendar.component(.year, from: date))
    }
    func shouldContinueAlarm(on date: Date, routine: Routine, now: Date) -> Bool {
        routine.alarmEnabled && routine.validationError == nil && dayKey(date) == dayKey(now)
            && ((!routine.verifiedDays.contains(dayKey(now)) && reasonOff(now, routine) == nil) || !dueExtras(routine, now: now).isEmpty)
    }
    /// Unverified extra alarms still ahead, earliest first.
    func extraAlarmDates(_ routine: Routine, now: Date) -> [(extra: ExtraAlarm, date: Date)] {
        guard routine.validationError == nil else { return [] }
        return routine.extraAlarms.filter { !routine.verifiedExtras.contains($0.id) }
            .map { ($0, time($0.minute, on: day($0.day))) }.filter { $0.date > now }.sorted { $0.date < $1.date }
    }
    /// Extra alarms of `now`'s day that have rung and still wait for verification.
    func dueExtras(_ routine: Routine, now: Date) -> [ExtraAlarm] {
        routine.extraAlarms.filter { $0.day == dayKey(now) && !routine.verifiedExtras.contains($0.id) && time($0.minute, on: now) <= now }
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
    /// near 100, so a pending extra alarm takes one of those days; verification, the stop intent
    /// and message requests all reschedule. Unlike alarmDates, today's backups stay wanted after
    /// the main alarm time has passed.
    func backupAlarmDates(_ routine: Routine, now: Date, workdays: Int = 2, interval: Int = 15) -> [(index: Int, date: Date, extra: ExtraAlarm?)] {
        guard routine.validationError == nil else { return [] }
        func rerings(after alarm: Date, extra: ExtraAlarm?) -> [(index: Int, date: Date, extra: ExtraAlarm?)] {
            (1...(12 * 60 / interval)).compactMap { k in
                let at = alarm.addingTimeInterval(TimeInterval(k * interval))
                return at > now && dayKey(at) == dayKey(alarm) ? (k, at, extra) : nil
            }
        }
        let extras = routine.extraAlarms.filter { !routine.verifiedExtras.contains($0.id) }
            .flatMap { rerings(after: time($0.minute, on: day($0.day)), extra: $0) }
        var result: [(index: Int, date: Date, extra: ExtraAlarm?)] = []
        var covered = 0
        for offset in 0..<14 where covered < (extras.isEmpty ? workdays : max(1, workdays - 1)) {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            guard reasonOff(date, routine) == nil, !routine.verifiedDays.contains(dayKey(date)) else { continue }
            let day = rerings(after: time(routine.alarmMinute, on: date), extra: nil)
            if !day.isEmpty { result += day; covered += 1 }
        }
        return result + extras
    }
    func slots(_ routine: Routine, on date: Date) -> [MessageSlot] {
        guard routine.validationError == nil else { return [] }
        func three(_ id: String, after minute: Int) -> [MessageSlot] {
            (0..<3).map { n in MessageSlot(id: "\(id)-\(n)", date: time(minute + Routine.messageDelay + n, on: date), ordinal: n + 1) }
        }
        let key = dayKey(date)
        var result: [MessageSlot] = []
        if reasonOff(date, routine) == nil, !routine.verifiedDays.contains(key), !routine.excludeHolidays || holidayCoverage(date) {
            result = three(key, after: routine.alarmMinute)
        }
        for extra in routine.extraAlarms where extra.day == key && !routine.verifiedExtras.contains(extra.id) {
            result += three(extra.id, after: extra.minute)
        }
        return result
    }
    func dueSlot(_ routine: Routine, now: Date) -> MessageSlot? {
        slots(routine, on: now).first { slot in
            let age = now.timeIntervalSince(slot.date)
            return age >= 0 && age < 60 && !routine.claimedSlots.contains(slot.id)
        }
    }
    private func mainDue(_ routine: Routine, now: Date) -> Bool {
        now >= time(routine.alarmMinute, on: now) && !routine.verifiedDays.contains(dayKey(now))
    }
    /// Verification opens at each alarm's time, so it can't be done the night before and slept through.
    func canVerify(_ routine: Routine, now: Date) -> Bool { mainDue(routine, now: now) || !dueExtras(routine, now: now).isEmpty }
    /// When verification opens next today, if anything is still left to verify.
    func nextVerification(_ routine: Routine, now: Date) -> Date? {
        let main = routine.verifiedDays.contains(dayKey(now)) ? [] : [time(routine.alarmMinute, on: now)]
        return (main + extraAlarmDates(routine, now: now).map(\.date)).filter { $0 > now && dayKey($0) == dayKey(now) }.min()
    }
    /// Verifies every alarm of today that has rung, leaving later ones (a nap after the morning) scheduled.
    func verify(_ input: String, routine: inout Routine, now: Date) -> Bool {
        guard input == routine.phrase, routine.validationError == nil, canVerify(routine, now: now) else { return false }
        if mainDue(routine, now: now) { routine.verifiedDays.insert(dayKey(now)) }
        routine.verifiedExtras.formUnion(dueExtras(routine, now: now).map(\.id))
        return true
    }
    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}
