import SwiftUI

struct HomeView: View {
    @Environment(RoutineStore.self) private var store
    @State private var showVerification = false
    private var tomorrow: Date { store.engine.calendar.date(byAdding: .day, value: 1, to: .now)! }
    private var quickOff: DayOff? { store.routine.daysOff.first { $0.start == store.engine.dayKey(tomorrow) && $0.end == $0.start && $0.title == "내일 쉬기" } }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TimelineView(.everyMinute) { context in hero(now: context.date) }.padding(24).frame(maxWidth: .infinity).background(Theme.surface, in: RoundedRectangle(cornerRadius: 28)).padding(.top, 16).padding(.bottom, 24)
                info("미인증 문자", subtitle: "1분 간격 3회 · 인증하면 남은 회차 취소", icon: "paperplane", value: RoutineEngine.clock(store.routine.messageMinute))
                Divider().overlay(Theme.border)
                NavigationLink { ContactsView() } label: {
                    info("알림 받을 사람", subtitle: store.routine.activeRecipients.isEmpty ? "문자 받을 사람을 선택해주세요" : store.routine.activeRecipients.map(\.name).joined(separator: ", "), icon: "person.crop.circle", value: "\(store.routine.activeRecipients.count)명")
                }.buttonStyle(.plain)
                Divider().overlay(Theme.border)
                TimelineView(.everyMinute) { context in extraAlarm(now: context.date) }
                Divider().overlay(Theme.border)
                restTomorrow
                if !store.routine.messageRemindersEnabled {
                    NavigationLink { AutomationView() } label: {
                        Label("문자 자동 발송이 꺼져 있어요", systemImage: "paperplane").font(.footnote).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.top, 8)
                }
                Text("모든 일정은 한국 시간 기준입니다.").font(.caption2).foregroundStyle(Theme.secondary).padding(.top, 28)
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.background(Theme.background).foregroundStyle(Theme.text).navigationTitle("WakeUpPlz").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVerification) { NavigationStack { VerificationView() } }
    }
    private func hero(now: Date) -> some View {
        let engine = store.engine, routine = store.routine
        let done = !engine.canVerify(routine, now: now)
            && (store.verifiedToday || routine.verifiedExtras.contains { $0.hasPrefix(engine.dayKey(now)) })
        let main = engine.alarmDates(routine, now: now, days: 370).first
        // An extra alarm takes the spotlight only while it comes before the next main alarm.
        let extra = engine.extraAlarmDates(routine, now: now).first.flatMap { e in main.map { e.date < $0 } ?? true ? e : nil }
        return VStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle" : "sunrise").font(.system(size: 30, weight: .light)).foregroundStyle(Theme.primary)
            Text(done ? "오늘 기상 인증 완료" : "다음 기상 알람").font(.subheadline).foregroundStyle(Theme.secondary)
            Text(RoutineEngine.clock(extra?.extra.minute ?? routine.alarmMinute)).font(.system(size: 80, weight: .regular, design: .rounded)).tracking(-4).minimumScaleFactor(0.6).lineLimit(1).foregroundStyle(Theme.primary)
            if let next = extra?.date ?? main { Text(next.formatted(.dateTime.month().day().weekday()) + (extra == nil ? " · 근무일" : " · 추가 알람")).font(.subheadline).foregroundStyle(Theme.secondary) }
            Text(routine.alarmEnabled ? "알람 켜짐" : "알람 꺼짐 · 설정에서 켜주세요").font(.caption).foregroundStyle(Theme.secondary)
            PrimaryButton(title: done ? "인증 완료 확인" : "기상 인증하기", icon: done ? "checkmark" : nil) { showVerification = true }.padding(.top, 16)
        }
    }
    /// Today's one-off alarm, e.g. a nap; it rings and messages like the morning alarm.
    private func extraAlarm(now: Date) -> some View {
        let engine = store.engine
        let extra = store.todayExtra
        let at = extra.map { engine.time($0.minute, on: now) }
        let lastMinute = 1427  // messages must fit before midnight, as with the main alarm
        let nowMinute = engine.calendar.component(.hour, from: now) * 60 + engine.calendar.component(.minute, from: now)
        let verified = store.routine.extraAlarms.last { $0.day == engine.dayKey(now) && store.routine.verifiedExtras.contains($0.id) }
        let subtitle: String
        if let extra, let at, at > now { subtitle = "\(RoutineEngine.clock(extra.minute))에 울려요 · 인증 안 하면 \(RoutineEngine.clock(extra.minute + Routine.messageDelay))부터 문자" }
        else if let extra { subtitle = "\(RoutineEngine.clock(extra.minute))에 울렸어요 · 기상 인증해주세요" }
        else if let verified { subtitle = "\(RoutineEngine.clock(verified.minute)) 인증 완료 · 켜면 한 번 더 울려요" }
        else { subtitle = "낮잠 등 오늘 한 번 더 · 알람과 문자가 똑같이 동작해요" }
        return HStack(spacing: 14) {
            Image(systemName: "alarm").font(.title3).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text("오늘 추가 알람").font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            if let at, at > now {
                DatePicker("추가 알람 시각", selection: Binding(get: { at }, set: { date in
                    let parts = engine.calendar.dateComponents([.hour, .minute], from: date)
                    store.setExtraAlarm(parts.hour! * 60 + parts.minute!)
                }), in: now...engine.time(lastMinute, on: now), displayedComponents: .hourAndMinute).labelsHidden()
            }
            Toggle("오늘 추가 알람", isOn: Binding(get: { extra != nil }, set: { on in
                // Default to an hour from now, rounded up to five minutes.
                store.setExtraAlarm(on ? min(lastMinute, (nowMinute + 60 + 4) / 5 * 5) : nil)
            })).labelsHidden().tint(Theme.primary).disabled(extra == nil && nowMinute >= lastMinute)
        }.padding(.vertical, 20)
    }
    private var tomorrowKey: String { store.engine.dayKey(tomorrow) }
    /// A registered day off other than the quick toggle; edited from the calendar instead.
    private var rangeOff: DayOff? { quickOff == nil ? store.routine.daysOff.first { $0.start <= tomorrowKey && tomorrowKey <= $0.end } : nil }
    /// Weekend or holiday regardless of the user's overrides.
    private var naturalOff: String? {
        var plain = store.routine; plain.daysOff = []; plain.workDays = []
        return store.engine.reasonOff(tomorrow, plain)
    }
    private var working: Bool { store.routine.workDays.contains(tomorrowKey) }
    private var restTomorrow: some View {
        let day = tomorrow.formatted(.dateTime.month().day().weekday())
        let subtitle: String
        if let rangeOff { subtitle = "\(day) · \(rangeOff.title) · 휴무일 탭에서 바꿀 수 있어요" }
        else if quickOff != nil { subtitle = "\(day) · 알람과 문자를 쉬어요" }
        else if let naturalOff { subtitle = working ? "\(day) · \(naturalOff)\(Self.copula(naturalOff).dropLast())지만 출근해요 · 알람이 울려요" : "\(day) · \(naturalOff)\(Self.copula(naturalOff)) 쉬어요 · 끄면 출근일로 알람이 울려요" }
        else { subtitle = "\(day) · 켜면 알람과 문자를 쉬어요" }
        return HStack(spacing: 14) {
            Image(systemName: "moon.zzz").font(.title3).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text("내일 쉬기").font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            Toggle("내일 쉬기", isOn: Binding(get: { store.engine.reasonOff(tomorrow, store.routine) != nil }, set: { rest in
                let key = tomorrowKey
                store.update { r in
                    if naturalOff != nil {
                        // Weekend/holiday: turning rest off marks tomorrow as a work day.
                        if rest { r.workDays.remove(key) } else { r.workDays.insert(key) }
                    } else if rest { r.daysOff.append(.init(start: key, end: key, title: "내일 쉬기")) }
                    else if let quickOff { r.daysOff.removeAll { $0.id == quickOff.id } }
                }
            })).labelsHidden().tint(Theme.primary).disabled(rangeOff != nil)
        }.padding(.vertical, 20)
    }
    /// "주말이라" vs "휴무라": pick the particle from the last syllable's final consonant.
    private static func copula(_ word: String) -> String {
        guard let scalar = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(scalar.value) else { return "이라" }
        return (scalar.value - 0xAC00) % 28 == 0 ? "라" : "이라"
    }
    private func info(_ title: String, subtitle: String, icon: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.subheadline.weight(.medium)); Text(subtitle).font(.caption).foregroundStyle(Theme.secondary) }
            Spacer(minLength: 8); Text(value).font(.body.monospacedDigit())
        }.padding(.vertical, 20)
    }
}
