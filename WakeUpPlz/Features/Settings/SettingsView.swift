import SwiftUI
import AlarmKit
import UserNotifications

struct SettingsView: View {
    @Environment(RoutineStore.self) private var store
    @State private var editPhrase = false
    @State private var phrase = ""
    @State private var message = ""
    @State private var editingMessage = false
    @State private var editingTime: RoutineTimeField?
    var body: some View {
        Form {
            Section("기상 설정") {
                Toggle("기상 알람", isOn: Binding(get: { store.routine.alarmEnabled }, set: { enabled in
                    Task {
                        if enabled {
                            do { guard try await AlarmManager.shared.requestAuthorization() == .authorized else { store.error = "설정 앱에서 WakeUpPlz 알람 권한을 허용해주세요."; return } }
                            catch { store.error = error.localizedDescription; return }
                        }
                        store.update { $0.alarmEnabled = enabled }
                    }
                }))
                Button { editingTime = .alarm } label: { LabeledContent("알람 시각", value: RoutineEngine.clock(store.routine.alarmMinute)) }.foregroundStyle(Theme.text)
                LabeledContent("첫 문자 시각", value: "알람 10분 뒤 · " + RoutineEngine.clock(store.routine.messageMinute))
                NavigationLink { ContactsView() } label: { LabeledContent("알림 받을 사람", value: "\(store.routine.activeRecipients.count)명 선택") }
                NavigationLink { SoundsView() } label: { LabeledContent("알람 사운드", value: store.routine.sound.replacingOccurrences(of: ".wav", with: "")) }
            }.listRowBackground(Theme.surface)
            Section("기상 인증") {
                Button { phrase = store.routine.phrase; editPhrase = true } label: { LabeledContent("인증 문구", value: store.routine.phrase) }.foregroundStyle(Theme.text)
                Button { message = store.routine.message; editingMessage = true } label: { Text("미인증 문자 내용") }.foregroundStyle(Theme.text)
                Text("미리 인증해도 당일 기상으로 인정해요. 공백과 문장부호까지 정확히 입력해야 해요.").font(.caption).foregroundStyle(Theme.secondary)
            }.listRowBackground(Theme.surface)
            Section("쉬는 날") {
                Toggle("주말 제외", isOn: binding(\.excludeWeekends))
                Toggle("대한민국 공휴일 제외", isOn: binding(\.excludeHolidays))
                NavigationLink("휴무일 관리") { DaysOffView() }
            }.listRowBackground(Theme.surface)
            Section("화면") {
                Picker("화면 모드", selection: binding(\.appearance)) {
                    Text("시스템").tag("system"); Text("라이트").tag("light"); Text("다크").tag("dark")
                }
            }.listRowBackground(Theme.surface)
            Section("자동화") {
                NavigationLink("자동화 연결 및 설정 안내") { AutomationView() }
                NavigationLink("발송 규칙 미리 테스트") { MessageLabView() }
            }.listRowBackground(Theme.surface)
            Section {
                if let expiry = SigningExpiry.date {
                    LabeledContent("앱 서명 만료", value: expiry.formatted(.dateTime.month().day().hour().minute()))
                }
                Text("예약은 앱을 열 때 앞으로 7일간 갱신됩니다. 서명은 Mac이 만료 전에 자동 갱신하며, 24시간 전까지 갱신되지 않으면 알림으로 알려드려요.").font(.caption).foregroundStyle(Theme.secondary)
            }.listRowBackground(Theme.surface)
        }.appForm().navigationTitle("설정")
            .sheet(item: $editingTime) { TimeEditor(field: $0) }
            .alert("인증 문구", isPresented: $editPhrase) {
                TextField("인증 문구", text: $phrase).autocorrectionDisabled()
                Button("취소", role: .cancel) {}
                Button("저장") { store.update { $0.phrase = phrase } }
            } message: { Text("1~80자. 오늘 이미 완료한 인증은 유지됩니다.") }
            .sheet(isPresented: $editingMessage) {
                NavigationStack {
                    Form { TextEditor(text: $message).frame(minHeight: 140) }.appForm().navigationTitle("문자 내용")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("취소") { editingMessage = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("저장") { if store.update({ $0.message = message }) { editingMessage = false } } }
                        }
                }.presentationDetents([.medium, .large])
            }
    }
    private func binding<T>(_ key: WritableKeyPath<Routine, T>) -> Binding<T> { Binding(get: { store.routine[keyPath: key] }, set: { value in store.update { $0[keyPath: key] = value } }) }
}
private enum RoutineTimeField: String, Identifiable {
    case alarm
    var id: String { rawValue }
    var title: String { "알람 시각" }
    var key: WritableKeyPath<Routine, Int> { \.alarmMinute }
}
private struct TimeEditor: View {
    @Environment(RoutineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let field: RoutineTimeField
    @State private var selection = Date.now
    @State private var problem: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(field.title, selection: $selection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden()
                if let problem { Text(problem).font(.footnote).foregroundStyle(.red) }
                Text("시각을 고른 뒤 저장하면 예약에 반영됩니다.").font(.footnote).foregroundStyle(Theme.secondary)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
                .navigationTitle(field.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("저장") {
                        let parts = store.engine.calendar.dateComponents([.hour, .minute], from: selection)
                        let minute = parts.hour! * 60 + parts.minute!
                        var candidate = store.routine
                        candidate[keyPath: field.key] = minute
                        if let error = candidate.validationError { problem = error; return }
                        if store.update({ $0[keyPath: field.key] = minute }) { dismiss() }
                    } }
                }
        }.onAppear { selection = store.engine.time(store.routine[keyPath: field.key], on: .now) }
            .presentationDetents([.medium])
    }
}
struct AutomationView: View {
    @Environment(RoutineStore.self) private var store
    var body: some View {
        Form {
            Section {
                Label("실제 문자 발송 미검증", systemImage: "link.badge.plus")
                Text("앱은 문자를 직접 자동 전송할 수 없어요. iOS 27의 알림 자동화와 단축어 연결을 실제 iPhone에서 확인해야 합니다.")
            }.listRowBackground(Theme.surface)
            Section("최초 연결 순서") {
                Text("1. 단축어에서 WakeUpPlz 알림을 받으면 실행하는 개인용 자동화를 만들어요.")
                Text("2. ‘WakeUpPlz 미인증 발송 요청 가져오기’를 실행해요. 빈 결과면 종료해요.")
                Text("3. JSON을 사전으로 변환하고 recipients의 각 번호에 text를 ‘메시지 보내기’로 전달해요.")
                Text("4. 잠금 상태 실행과 인증 후 취소를 확인한 뒤 사용해요. 시각은 앱에서만 변경합니다.")
            }.listRowBackground(Theme.surface)
            Section {
                Toggle("자동화용 알림 예약", isOn: Binding(get: { store.routine.messageRemindersEnabled }, set: { enabled in
                    Task {
                        if enabled {
                            guard !store.routine.activeRecipients.isEmpty else { store.error = "먼저 문자를 받을 사람을 선택해주세요."; return }
                            do { guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) else { store.error = "알림 권한이 필요해요."; return } }
                            catch { store.error = error.localizedDescription; return }
                        }
                        store.update { $0.messageRemindersEnabled = enabled }
                    }
                }))
            } footer: { Text("이 스위치는 알림만 예약합니다. 단축어 연결 완료나 문자 수신을 보장하지 않아요. 각 요청은 1회만 제공되며 전송 실패 시 자동 재시도하지 않습니다.") }
            Section("알람 안내") {
                Text("인증 전에는 알람을 꺼도 다시 울려요. 밀어서 끄면 10초 뒤, 측면 버튼 등 다른 방법으로 끄면 1분 안에 다시 울리고, 알람 12분 뒤까지 반복돼요. 기상 인증하면 모두 취소합니다. 강제 종료·권한 변경 등 모든 상황에서 재알림이 보장되지는 않습니다.")
                Text("알람 출력은 iPhone의 시스템 제한을 따릅니다. 최대 음량을 초과하거나 음량을 강제로 고정할 수 없습니다.")
            }.font(.footnote).listRowBackground(Theme.surface)
        }.appForm().navigationTitle("자동화 연결").navigationBarTitleDisplayMode(.inline)
    }
}
struct MessageLabView: View {
    @State private var routine = Routine()
    @State private var minute = 510
    @State private var log: [String] = []
    let engine = RoutineEngine()
    var now: Date { engine.time(minute, on: engine.day("2026-10-22")) }
    var body: some View {
        Form {
            Section { Text("가상 시간 테스트 · 실제 문자 발송 없음"); Text(RoutineEngine.clock(minute)).font(.largeTitle.monospacedDigit()); Stepper("1분 이동", value: $minute, in: 509...514) }
            Section {
                Button("현재 회차 확인") {
                    if let slot = engine.dueSlot(routine, now: now) { routine.claimedSlots.insert(slot.id); log.append("\(slot.ordinal)회차 요청 생성") }
                    else { log.append("발송할 요청 없음") }
                }
                Button("기상 인증 시뮬레이션") { _ = engine.verify(routine.phrase, routine: &routine, now: now); log.append("인증 완료 · 남은 회차 취소") }
                Button("초기화") { routine = Routine(); minute = 510; log = [] }
            }
            Section("결과") { ForEach(Array(log.enumerated()), id: \.offset) { _, line in Text(line) } }
        }.appForm().navigationTitle("발송 규칙 테스트").navigationBarTitleDisplayMode(.inline)
    }
}
