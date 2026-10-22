import SwiftUI

struct HomeView: View {
    @Environment(RoutineStore.self) private var store
    @State private var showVerification = false
    private var next: Date? { store.engine.alarmDates(store.routine, now: .now, days: 370).first }
    private var tomorrow: Date { store.engine.calendar.date(byAdding: .day, value: 1, to: .now)! }
    private var quickOff: DayOff? { store.routine.daysOff.first { $0.start == store.engine.dayKey(tomorrow) && $0.end == $0.start && $0.title == "내일 쉬기" } }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Image(systemName: store.verifiedToday ? "checkmark.circle" : "sunrise").font(.system(size: 30, weight: .light)).foregroundStyle(Theme.primary)
                    Text(store.verifiedToday ? "오늘 기상 인증 완료" : "다음 기상 알람").font(.subheadline).foregroundStyle(Theme.secondary)
                    Text(RoutineEngine.clock(store.routine.alarmMinute)).font(.system(size: 80, weight: .regular, design: .rounded)).tracking(-4).minimumScaleFactor(0.6).lineLimit(1).foregroundStyle(Theme.primary)
                    if let next { Text(next.formatted(.dateTime.month().day().weekday()) + " · 근무일").font(.subheadline).foregroundStyle(Theme.secondary) }
                    Text(store.routine.alarmEnabled ? "알람 켜짐" : "알람 꺼짐 · 설정에서 켜주세요").font(.caption).foregroundStyle(Theme.secondary)
                    PrimaryButton(title: store.verifiedToday ? "인증 완료 확인" : "기상 인증하기", icon: store.verifiedToday ? "checkmark" : nil) { showVerification = true }.padding(.top, 16)
                }.padding(24).frame(maxWidth: .infinity).background(Theme.surface, in: RoundedRectangle(cornerRadius: 28)).padding(.top, 16).padding(.bottom, 24)
                info("미인증 문자", subtitle: "1분 간격 3회 · 인증하면 남은 회차 취소", icon: "paperplane", value: RoutineEngine.clock(store.routine.messageMinute))
                Divider().overlay(Theme.border)
                NavigationLink { ContactsView() } label: {
                    info("알림 받을 사람", subtitle: store.routine.activeRecipients.isEmpty ? "문자 받을 사람을 선택해주세요" : store.routine.activeRecipients.map(\.name).joined(separator: ", "), icon: "person.crop.circle", value: "\(store.routine.activeRecipients.count)명")
                }.buttonStyle(.plain)
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
    /// Tomorrow is already off for another reason (weekend, holiday, a registered day off).
    private var otherReasonOff: String? { quickOff == nil ? store.engine.reasonOff(tomorrow, store.routine) : nil }
    private var restTomorrow: some View {
        let day = tomorrow.formatted(.dateTime.month().day().weekday())
        let subtitle = otherReasonOff.map { "\(day) · \($0)\(Self.copula($0)) 쉬어요" }
            ?? (quickOff == nil ? "\(day) · 켜면 알람과 문자를 쉬어요" : "\(day) · 알람과 문자를 쉬어요")
        return HStack(spacing: 14) {
            Image(systemName: "moon.zzz").font(.title3).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text("내일 쉬기").font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            if otherReasonOff == nil {
                Toggle("내일 쉬기", isOn: Binding(get: { quickOff != nil }, set: { on in
                    store.update { r in
                        if on { let key = store.engine.dayKey(tomorrow); r.daysOff.append(.init(start: key, end: key, title: "내일 쉬기")) }
                        else if let quickOff { r.daysOff.removeAll { $0.id == quickOff.id } }
                    }
                })).labelsHidden().tint(Theme.primary)
            } else {
                Text("쉬는 날").font(.subheadline).foregroundStyle(Theme.secondary)
            }
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
