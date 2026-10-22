import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
import UserNotifications

struct WakeMetadata: AlarmMetadata { var day: String }
@MainActor final class ScheduleService {
    static let shared = ScheduleService()
    private let engine = RoutineEngine()
    private var lastAlarmConfiguration = UserDefaults.standard.string(forKey: "lastAlarmConfiguration")
    func reconcile(_ routine: Routine) async throws -> Date? {
        let now = Date.now
        let dates = routine.alarmEnabled ? engine.alarmDates(routine, now: now) : []
        let desired = Dictionary(uniqueKeysWithValues: dates.map { (alarmID($0), $0) })
        let configuration = "\(routine.alarmMinute)-\(routine.sound)"
        let alarms = try AlarmManager.shared.alarms
        for alarm in alarms {
            var keep = false
            var preserveCurrentAlarm = false
            if case .fixed(let date) = alarm.schedule {
                keep = desired[alarm.id] == date
                // Opening the app or editing an unrelated setting must not silence an
                // alert that has already fired (and is absent from future alarmDates).
                preserveCurrentAlarm = engine.shouldContinueAlarm(on: date, routine: routine, now: now)
                    && (alarm.state == .alerting || (alarm.id.uuidString.hasPrefix("BBBBBBBB") && date > now))
            }
            if !preserveCurrentAlarm && (!keep || (lastAlarmConfiguration != nil && lastAlarmConfiguration != configuration)) {
                try AlarmManager.shared.cancel(id: alarm.id)
            }
        }
        let existing = try Set(AlarmManager.shared.alarms.map(\.id))
        for (id, date) in desired where !existing.contains(id) { try await schedule(id: id, date: date, routine: routine) }
        lastAlarmConfiguration = configuration
        UserDefaults.standard.set(configuration, forKey: "lastAlarmConfiguration")
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("wup-") }
        let slots = routine.messageRemindersEnabled && !routine.recipients.isEmpty ? (0..<7).flatMap { offset in
            engine.slots(routine, on: engine.calendar.date(byAdding: .day, value: offset, to: now)!).filter { $0.date > now && !routine.claimedSlots.contains($0.id) }
        } : []
        let desiredNotifications = Dictionary(uniqueKeysWithValues: slots.map { ("wup-" + $0.id, $0.date) })
        let unchanged = Set(pending.filter { request in
            guard let date = desiredNotifications[request.identifier], let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
            return trigger.nextTriggerDate() == date
        }.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { !unchanged.contains($0.identifier) }.map(\.identifier))
        for slot in slots where !unchanged.contains("wup-" + slot.id) {
            let content = UNMutableNotificationContent()
            content.title = "WakeUpPlz 기상 확인"
            content.body = "아직 기상 인증을 하지 않았어요. \(slot.ordinal)/3회차 확인입니다."
            content.sound = .default
            content.userInfo = ["slot": slot.id]
            var parts = engine.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: slot.date)
            parts.timeZone = engine.calendar.timeZone
            try await center.add(UNNotificationRequest(identifier: "wup-" + slot.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
        return dates.last
    }
    func retryIfNeeded(day: String) async throws {
        let routine = RoutineStore.shared.routine
        let now = Date.now
        guard engine.shouldContinueAlarm(on: engine.day(day), routine: routine, now: now) else { return }
        let date = now.addingTimeInterval(10)
        guard engine.dayKey(date) == day else { return }
        // Fresh ID per retry so repeated stops never collide with a previous retry; the
        // BBBBBBBB prefix lets reconcile keep it until verification.
        let id = UUID(uuidString: "BBBBBBBB" + UUID().uuidString.dropFirst(8))!
        try await schedule(id: id, date: date, routine: routine)
    }
    private func alarmID(_ date: Date) -> UUID {
        let key = engine.dayKey(date).replacingOccurrences(of: "-", with: "")
        return UUID(uuidString: "AAAAAAAA-0000-0000-0000-" + key + "0000")!
    }
    private func schedule(id: UUID, date: Date, routine: Routine) async throws {
        let day = engine.dayKey(date)
        let alert = AlarmPresentation.Alert(title: "기상 인증이 필요해요", stopButton: AlarmButton(text: "중지", textColor: .white, systemImageName: "stop.fill"))
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: WakeMetadata(day: day), tintColor: Color(red: 0.36, green: 0.40, blue: 0.44))
        let config = AlarmManager.AlarmConfiguration.alarm(schedule: .fixed(date), attributes: attributes, stopIntent: RetryAlarmIntent(day: day), sound: .named(routine.sound))
        _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
    }
}
