import Foundation
import Testing
@testable import WakeCore
@Suite(.serialized) struct RoutineTests {  // downloadedHolidaysReplaceBundledYear mutates shared holiday data
    let engine = RoutineEngine()
    func at(_ minute: Int, day: String = "2026-10-22") -> Date { engine.time(minute, on: engine.day(day)) }
    @Test func verificationOpensAtAlarmIsExactAndCancelsSlots() {
        var r = Routine()
        #expect(!engine.verify("일어났어!", routine: &r, now: at(499)))  // before the 08:20 alarm
        #expect(!engine.verify("일어났어! ", routine: &r, now: at(500)))
        #expect(engine.verify("일어났어!", routine: &r, now: at(500)))
        #expect(engine.slots(r, on: at(510)).isEmpty)
        #expect(engine.alarmDates(r, now: at(500)).allSatisfy { engine.dayKey($0) != "2026-10-22" })
        #expect(engine.slots(r, on: at(510, day: "2026-10-23")).count == 3)
    }
    @Test func cancelAfterFirstAndPreventDuplicates() {
        var r = Routine()
        #expect(engine.dueSlot(r, now: at(509)) == nil)
        let first = engine.dueSlot(r, now: at(510))!
        r.claimedSlots.insert(first.id)
        #expect(engine.dueSlot(r, now: at(510)) == nil)
        #expect(engine.dueSlot(r, now: at(511))?.ordinal == 2)
        #expect(engine.verify(r.phrase, routine: &r, now: at(511)))
        #expect(engine.dueSlot(r, now: at(512)) == nil)
    }
    @Test func noCatchupBurstAndMidnightBoundary() {
        let r = Routine()
        #expect(engine.dueSlot(r, now: at(512))?.ordinal == 3)
        #expect(engine.dueSlot(r, now: at(513)) == nil)
        var invalid = r
        invalid.alarmMinute = 1428
        #expect(invalid.messageMinute == 1438)
        #expect(invalid.validationError != nil)
        #expect(engine.slots(invalid, on: at(510)).isEmpty)
    }
    @Test func weekendsHolidaysAndRanges() {
        var r = Routine()
        #expect(engine.reasonOff(engine.day("2026-10-24"), r) == "주말")
        #expect(engine.reasonOff(engine.day("2026-10-05"), r) == "대체공휴일")
        r.daysOff = [.init(start: "2026-10-22", end: "2026-10-23", title: "휴가")]
        #expect(engine.slots(r, on: at(510)).isEmpty)
        #expect(engine.slots(r, on: at(510, day: "2026-10-23")).isEmpty)
        #expect(engine.alarmDates(r, now: at(400)).first == at(500, day: "2026-10-26"))
    }
    @Test func unsupportedHolidayYearBlocksMessage() {
        #expect(engine.slots(Routine(), on: engine.day("2028-01-03")).isEmpty)
    }
    @Test func customPhraseAndPhoneNormalization() {
        var r = Routine(); r.phrase = "좋은 아침 ☀️"
        #expect(!engine.verify("일어났어!", routine: &r, now: at(505)))
        #expect(engine.verify("좋은 아침 ☀️", routine: &r, now: at(505)))
        #expect(Recipient.normalized("+82 10-1234-5678") == Recipient.normalized("010-1234-5678"))
    }
    @Test func ringingAlarmSurvivesRefreshUntilVerifiedOrExcluded() {
        var r = Routine(); r.alarmEnabled = true
        let fired = at(500), now = at(501)
        #expect(!engine.alarmDates(r, now: now).contains(fired))
        #expect(engine.shouldContinueAlarm(on: fired, routine: r, now: now))
        r.appearance = "dark"
        #expect(engine.shouldContinueAlarm(on: fired, routine: r, now: now))
        #expect(!engine.shouldContinueAlarm(on: fired, routine: r, now: at(501, day: "2026-10-23")))
        r.verifiedDays.insert(engine.dayKey(now))
        #expect(!engine.shouldContinueAlarm(on: fired, routine: r, now: now))
        r.verifiedDays.removeAll(); r.alarmEnabled = false
        #expect(!engine.shouldContinueAlarm(on: fired, routine: r, now: now))
        r.alarmEnabled = true
        r.daysOff = [.init(start: "2026-10-22", end: "2026-10-22", title: "휴무")]
        #expect(!engine.shouldContinueAlarm(on: fired, routine: r, now: now))
    }
    @Test func onlySelectedRecipientsAndLegacyDecode() throws {
        var r = Routine()
        r.recipients = [.init(name: "A", phone: "01011112222"), .init(name: "B", phone: "01033334444", selected: false)]
        #expect(r.activeRecipients.map(\.name) == ["A"])
        let legacy = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"C","phone":"01055556666"}"#
        #expect(try JSONDecoder().decode(Recipient.self, from: Data(legacy.utf8)).selected)
    }
    @Test func backupAlarmsSurviveMainAlarmUntilVerified() {
        var r = Routine()
        let afterMain = at(503) // Thu 2026-10-22, alarm 08:20
        let backups = engine.backupAlarmDates(r, now: afterMain)
        let today = backups.filter { engine.dayKey($0.date) == "2026-10-22" }
        #expect(today.count == 36 && today.first?.date == at(503).addingTimeInterval(15))
        #expect(today.last?.date == at(512))
        #expect(Set(backups.map { engine.dayKey($0.date) }) == ["2026-10-22", "2026-10-23"])
        r.verifiedDays.insert("2026-10-22")
        // Friday verified-out of today: next two workdays skip the weekend.
        #expect(Set(engine.backupAlarmDates(r, now: afterMain).map { engine.dayKey($0.date) }) == ["2026-10-23", "2026-10-26"])
        #expect(engine.backupAlarmDates(r, now: at(400, day: "2026-10-23")).count == 96)
    }
    @Test func workDayOverridesWeekendAndHoliday() {
        var r = Routine()
        r.workDays = ["2026-10-24", "2026-10-09"]  // Saturday, 한글날
        #expect(engine.reasonOff(engine.day("2026-10-24"), r) == nil)
        #expect(engine.reasonOff(engine.day("2026-10-09"), r) == nil)
        #expect(engine.slots(r, on: engine.day("2026-10-24")).count == 3)
        r.daysOff = [.init(start: "2026-10-24", end: "2026-10-24", title: "휴가")]
        #expect(engine.reasonOff(engine.day("2026-10-24"), r) == "휴가")
    }
    @Test func legacyRoutineDecodesWithDefaults() throws {
        let saved = #"{"alarmMinute":420,"phrase":"기상","recipients":[]}"#
        let r = try JSONDecoder().decode(Routine.self, from: Data(saved.utf8))
        #expect(r.alarmMinute == 420 && r.phrase == "기상" && r.workDays.isEmpty && r.excludeWeekends)
    }
    @Test func napAfterVerifiedMorningRingsAndMessagesUntilVerified() {
        var r = Routine(); r.alarmEnabled = true
        #expect(engine.verify(r.phrase, routine: &r, now: at(505)))  // Thu morning
        r.extraAlarms = [.init(day: "2026-10-22", minute: 900)]  // 15:00 nap
        #expect(!engine.canVerify(r, now: at(899)))
        #expect(engine.nextVerification(r, now: at(899)) == at(900))
        #expect(engine.extraAlarmDates(r, now: at(899)).map(\.date) == [at(900)])
        #expect(engine.slots(r, on: at(0)).map(\.id) == ["2026-10-22+1500-0", "2026-10-22+1500-1", "2026-10-22+1500-2"])
        #expect(engine.dueSlot(r, now: at(910))?.id == "2026-10-22+1500-0")
        #expect(engine.shouldContinueAlarm(on: at(900), routine: r, now: at(901)))
        let backups = engine.backupAlarmDates(r, now: at(899))
        #expect(backups.filter { $0.extra != nil }.count == 48)
        #expect(Set(backups.filter { $0.extra == nil }.map { engine.dayKey($0.date) }) == ["2026-10-23"])  // one main day while a nap is pending
        #expect(engine.verify(r.phrase, routine: &r, now: at(902)))
        #expect(!engine.canVerify(r, now: at(903)) && engine.slots(r, on: at(0)).isEmpty)
        #expect(!engine.shouldContinueAlarm(on: at(900), routine: r, now: at(903)))
        #expect(engine.backupAlarmDates(r, now: at(903)).count == 96)
    }
    @Test func napOnWeekendIgnoresDayOffAndVerifiesSeparately() {
        var r = Routine()
        r.extraAlarms = [.init(day: "2026-10-22", minute: 400), .init(day: "2026-10-24", minute: 840)]  // Thu 06:40, Sat 14:00
        #expect(engine.slots(r, on: engine.day("2026-10-24")).count == 3)
        #expect(engine.verify(r.phrase, routine: &r, now: at(401)))  // before the 08:20 alarm
        #expect(r.verifiedExtras == ["2026-10-22+0640"] && r.verifiedDays.isEmpty)
        #expect(engine.nextVerification(r, now: at(401)) == at(500))
        #expect(engine.slots(r, on: at(0)).count == 3)  // morning messages still on
        r.extraAlarms.append(.init(day: "2026-10-22", minute: 1428))
        #expect(r.validationError != nil)
    }
    @Test func downloadedHolidaysReplaceBundledYear() {
        KoreanHolidays.setDownloaded([2028: ["2028-01-03": "임시공휴일"]])
        defer { KoreanHolidays.setDownloaded([:]) }
        #expect(KoreanHolidays.name(for: "2028-01-03") == "임시공휴일")
        #expect(engine.slots(Routine(), on: engine.day("2028-01-04")).count == 3)  // 2028 now covered
        #expect(KoreanHolidays.name(for: "2026-10-09") == "한글날")  // bundled year untouched
    }
}
