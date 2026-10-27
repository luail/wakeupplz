import Foundation
import Observation

@MainActor @Observable final class RoutineStore {
    static let shared = RoutineStore()
    private(set) var routine = Routine()
    var error: String?
    var scheduling = false
    var scheduledThrough: Date?
    let engine = RoutineEngine()
    private let file: URL
    private var scheduleTask: Task<Void, Never>?
    private var canSave = true
    init() {
        _ = HolidayService.shared  // load downloaded holidays before any schedule or intent runs
        let folder = URL.applicationSupportDirectory.appending(path: "WakeUpPlz")
        file = folder.appending(path: "routine.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                routine = try JSONDecoder().decode(Routine.self, from: Data(contentsOf: file))
            }
        } catch {
            canSave = false
            self.error = "저장된 설정을 읽을 수 없어요. 기존 데이터를 보존했습니다. \(error.localizedDescription)"
        }
    }
    @discardableResult func update(_ change: (inout Routine) -> Void) -> Bool {
        var updated = routine; change(&updated)
        if let problem = updated.validationError { error = problem; return false }
        guard canSave else { error = "저장 파일 오류를 먼저 해결해주세요. 기존 설정은 덮어쓰지 않습니다."; return false }
        do {
            let data = try JSONEncoder().encode(updated)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            routine = updated
            refreshSchedules()
            return true
        } catch { self.error = "설정을 저장하지 못했어요. \(error.localizedDescription)"; return false }
    }
    func verify(_ input: String, now: Date = .now) -> Bool {
        var verified = routine
        guard engine.verify(input, routine: &verified, now: now) else { return false }
        return update { $0.verifiedDays = verified.verifiedDays; $0.verifiedExtras = verified.verifiedExtras }
    }
    var verifiedToday: Bool { routine.verifiedDays.contains(engine.dayKey(.now)) }
    /// Today's extra alarm that still waits for verification, whether or not it has rung yet.
    var todayExtra: ExtraAlarm? { routine.extraAlarms.first { $0.day == engine.dayKey(.now) && !routine.verifiedExtras.contains($0.id) } }
    /// Sets today's one-off alarm, or removes it with nil. Verified ones stay so their alarms and
    /// messages remain cancelled; earlier days are pruned.
    @discardableResult func setExtraAlarm(_ minute: Int?, now: Date = .now) -> Bool {
        let today = engine.dayKey(now)
        if let minute, engine.time(minute, on: now) <= now { error = "지난 시각은 고를 수 없어요."; return false }
        return update { r in
            r.extraAlarms.removeAll { $0.day < today || ($0.day == today && !r.verifiedExtras.contains($0.id)) }
            r.verifiedExtras = r.verifiedExtras.filter { $0 >= today }
            if let minute { r.extraAlarms.append(.init(day: today, minute: minute)) }
        }
    }
    #if DEBUG
    /// Test-only: clears today's verification and message claims so alarms can be re-run.
    func resetToday() {
        let key = engine.dayKey(.now)
        update { r in
            r.verifiedDays.remove(key)
            r.verifiedExtras = r.verifiedExtras.filter { !$0.hasPrefix(key) }
            r.claimedSlots = r.claimedSlots.filter { !$0.hasPrefix(key) }
        }
    }
    #endif
    func refreshSchedules() {
        // Serialize OS updates: a newer edit waits for in-flight scheduling before reconciling.
        let previous = scheduleTask
        scheduleTask = Task {
            await previous?.value
            scheduling = true
            defer { scheduling = false }
            do { scheduledThrough = try await ScheduleService.shared.reconcile(routine) }
            catch { self.error = "예약을 적용하지 못했어요. 다시 앱을 열어 확인해주세요. \(error.localizedDescription)" }
        }
    }
    /// For intents: the process may be suspended right after perform returns.
    func refreshSchedulesAndWait() async {
        refreshSchedules()
        await scheduleTask?.value
    }
    func addRecipient(name: String, phone: String) -> Bool {
        let number = Recipient.normalized(phone)
        guard (7...15).contains(number.filter(\.isNumber).count) else { error = "유효한 전화번호를 선택해주세요."; return false }
        guard !routine.recipients.contains(where: { Recipient.normalized($0.phone) == number }) else { error = "이미 등록한 번호예요."; return false }
        return update { $0.recipients.append(Recipient(name: name.isEmpty ? number : name, phone: number)) }
    }
    func claimMessage(now: Date = .now) -> MessagePayload? {
        guard routine.messageRemindersEnabled, !routine.activeRecipients.isEmpty,
              let slot = engine.dueSlot(routine, now: now) else { return nil }
        let payload = MessagePayload(id: slot.id, ordinal: slot.ordinal, recipients: routine.activeRecipients.map(\.phone), text: routine.message)
        // Persist before handing off. A failed Shortcuts send is not retried automatically.
        guard update({ $0.claimedSlots.insert(slot.id) }) else { return nil }
        return payload
    }
}
struct MessagePayload: Codable {
    var id: String
    var ordinal: Int
    var recipients: [String]
    var text: String
}
