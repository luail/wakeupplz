import Foundation
import Testing
@testable import WakeCore
struct RoutineTests {
    let engine = RoutineEngine()
    func at(_ minute: Int, day: String = "2026-10-22") -> Date { engine.time(minute, on: engine.day(day)) }
    @Test func earlyVerificationIsExactAndCancelsAllSlots() {
        var r = Routine()
        #expect(!engine.verify("일어났어! ", routine: &r, now: at(400)))
        #expect(engine.verify("일어났어!", routine: &r, now: at(400)))
        #expect(engine.slots(r, on: at(510)).isEmpty)
        #expect(engine.alarmDates(r, now: at(400)).allSatisfy { engine.dayKey($0) != "2026-10-22" })
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
        #expect(!engine.verify("일어났어!", routine: &r, now: at(400)))
        #expect(engine.verify("좋은 아침 ☀️", routine: &r, now: at(400)))
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
}
