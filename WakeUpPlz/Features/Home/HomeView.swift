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
                Button {
                    store.update { r in
                        if let quickOff { r.daysOff.removeAll { $0.id == quickOff.id } }
                        else { let key = store.engine.dayKey(tomorrow); r.daysOff.append(.init(start: key, end: key, title: "내일 쉬기")) }
                    }
                } label: {
                    HStack { Image(systemName: "moon"); Text(quickOff == nil ? "내일 쉬기" : "내일 쉬기 취소"); Spacer(); Text(store.engine.reasonOff(tomorrow, store.routine) ?? "근무일").font(.caption); Image(systemName: "chevron.right").font(.caption) }.padding(.vertical, 24)
                }.buttonStyle(.plain)
                NavigationLink { AutomationView() } label: {
                    Label("문자 자동화 연결이 필요해요", systemImage: "link").font(.footnote).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                if store.scheduling { ProgressView("예약 적용 중").font(.caption).padding(.top) }
                Text("모든 일정은 한국 시간 기준입니다.").font(.caption2).foregroundStyle(Theme.secondary).padding(.top, 28)
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.background(Theme.background).foregroundStyle(Theme.text).navigationTitle("WakeUpPlz").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVerification) { NavigationStack { VerificationView() } }
    }
    private func info(_ title: String, subtitle: String, icon: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.subheadline.weight(.medium)); Text(subtitle).font(.caption).foregroundStyle(Theme.secondary) }
            Spacer(minLength: 8); Text(value).font(.body.monospacedDigit())
        }.padding(.vertical, 20)
    }
}
