import SwiftUI

struct DaysOffView: View {
    @Environment(RoutineStore.self) private var store
    @State private var month = Date.now
    @State private var edit: DayOff?
    @State private var adding = false
    private var calendar: Calendar { store.engine.calendar }
    private var first: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: month))! }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("이전 달")
                    Spacer(); Text(month.formatted(.dateTime.year().month(.wide))).font(.title3.weight(.semibold)); Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("다음 달")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                    ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { title in Text(title).font(.caption).foregroundStyle(Theme.secondary) }
                    ForEach((1 - calendar.component(.weekday, from: first))..<0, id: \.self) { _ in Color.clear.frame(height: 44) }
                    ForEach(Array(calendar.range(of: .day, in: .month, for: month) ?? 1..<2), id: \.self) { number in
                        let date = calendar.date(byAdding: .day, value: number - 1, to: first)!
                        let off = store.engine.reasonOff(date, store.routine)
                        Button {
                            let key = store.engine.dayKey(date)
                            edit = store.routine.daysOff.first { $0.start <= key && key <= $0.end } ?? DayOff(start: key, end: key, title: "휴무")
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(number)").font(.body.monospacedDigit())
                                Circle().fill(off == nil ? Color.clear : Theme.primary).frame(width: 4, height: 4)
                            }.frame(maxWidth: .infinity, minHeight: 44).background(calendar.isDateInToday(date) ? Theme.primary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).foregroundStyle(off == nil ? Theme.text : Theme.secondary).accessibilityLabel("\(number)일, \(off ?? "근무일")")
                    }
                }
                Text("점이 있는 날은 쉬는 날이에요. 날짜를 눌러 휴무를 등록하거나 수정할 수 있어요.").font(.caption).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
                PrimaryButton(title: "휴무일 등록", icon: "plus") { adding = true }
                VStack(spacing: 0) {
                    ForEach(store.routine.daysOff.sorted { $0.start < $1.start }) { off in
                        Button { edit = off } label: {
                            HStack { VStack(alignment: .leading, spacing: 6) { Text(off.title); Text(off.start == off.end ? off.start : "\(off.start) — \(off.end)").font(.caption).foregroundStyle(Theme.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.vertical, 18)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
                Text("대한민국 공휴일 데이터: 2026–2027년\n임시공휴일은 자료 갱신 또는 직접 등록이 필요합니다.").font(.caption2).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(24)
        }.background(Theme.background).foregroundStyle(Theme.text).navigationTitle("휴무일")
            .sheet(isPresented: $adding) { DayOffEditor(off: DayOff(start: store.engine.dayKey(.now), end: store.engine.dayKey(.now), title: "휴무")) }
            .sheet(item: $edit) { DayOffEditor(off: $0) }
    }
    private func move(_ offset: Int) { month = calendar.date(byAdding: .month, value: offset, to: first)! }
}
private struct DayOffEditor: View {
    @Environment(RoutineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let off: DayOff
    @State private var title = ""
    @State private var start = Date.now
    @State private var end = Date.now
    var body: some View {
        NavigationStack {
            Form {
                TextField("휴무 이름", text: $title)
                DatePicker("시작일", selection: $start, displayedComponents: .date).onChange(of: start) { _, value in if end < value { end = value } }
                DatePicker("마지막 날", selection: $end, in: start..., displayedComponents: .date)
                if store.routine.daysOff.contains(where: { $0.id == off.id }) {
                    Button("휴무일 삭제", role: .destructive) { if store.update({ $0.daysOff.removeAll { $0.id == off.id } }) { dismiss() } }
                }
            }.appForm().navigationTitle("휴무일 편집").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("저장") {
                        if store.update({ r in
                            r.daysOff.removeAll { $0.id == off.id }
                            r.daysOff.append(DayOff(id: off.id, start: store.engine.dayKey(start), end: store.engine.dayKey(end), title: title.isEmpty ? "휴무" : title))
                        }) { dismiss() }
                    } }
                }
        }.onAppear { title = off.title; start = store.engine.day(off.start); end = store.engine.day(off.end) }.presentationDetents([.medium, .large])
    }
}
