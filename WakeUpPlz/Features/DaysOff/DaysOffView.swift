import SwiftUI

struct DaysOffView: View {
    @Environment(RoutineStore.self) private var store
    @State private var month = Date.now
    @State private var edit: DayOff?
    @State private var adding = false
    @State private var workChoice: Date?
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
                    ForEach((1 - calendar.component(.weekday, from: first))..<0, id: \.self) { _ in Color.clear.frame(height: 50) }
                    ForEach(Array(calendar.range(of: .day, in: .month, for: month) ?? 1..<2), id: \.self) { number in
                        let date = calendar.date(byAdding: .day, value: number - 1, to: first)!
                        let off = store.engine.reasonOff(date, store.routine)
                        let kind = dayKind(date)
                        Button {
                            let key = store.engine.dayKey(date)
                            if kind == .weekend || kind == .holiday || kind == .extraWork { workChoice = date }
                            else { edit = store.routine.daysOff.first { $0.start <= key && key <= $0.end } ?? DayOff(start: key, end: key, title: "휴무") }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(number)").font(.body.monospacedDigit().weight(kind == .work ? .regular : .semibold))
                                // Holiday/day-off name in the cell; weekends need no label.
                                Text(kind == .extraWork ? "출근" : kind == .holiday || kind == .personal ? (off ?? "") : " ").font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                            }.padding(.horizontal, 2).frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(kind == .personal ? Color.white : kind == .work ? Theme.text : kind == .holiday || kind == .extraWork ? Theme.primary : Theme.secondary)
                            .background(kind.fill, in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                if calendar.isDateInToday(date) { RoundedRectangle(cornerRadius: 12).stroke(Theme.primary, lineWidth: 1.5) }
                                else if kind == .extraWork { RoundedRectangle(cornerRadius: 12).stroke(Theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
                            }
                        }.buttonStyle(.plain).accessibilityLabel("\(number)일, \(off ?? "근무일")")
                    }
                }
                HStack(spacing: 14) {
                    legend(DayKind.personal.fill, "내 휴무"); legend(DayKind.holiday.fill, "공휴일"); legend(DayKind.weekend.fill, "주말")
                    HStack(spacing: 6) { RoundedRectangle(cornerRadius: 4).stroke(Theme.primary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 14, height: 14); Text("출근") }
                    HStack(spacing: 6) { RoundedRectangle(cornerRadius: 4).stroke(Theme.primary, lineWidth: 1.5).frame(width: 14, height: 14); Text("오늘") }
                    Spacer(minLength: 0)
                }.font(.caption).foregroundStyle(Theme.secondary)
                Text("색이 칠해진 날은 알람과 문자를 쉬어요. 날짜를 눌러 휴무를 등록하거나 수정할 수 있어요.").font(.caption).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
                PrimaryButton(title: "휴무일 등록", icon: "plus") { adding = true }
                VStack(spacing: 0) {
                    ForEach(store.routine.daysOff.sorted { $0.start < $1.start }) { off in
                        Button { edit = off } label: {
                            HStack { VStack(alignment: .leading, spacing: 6) { Text(off.title); Text(off.start == off.end ? off.start : "\(off.start) — \(off.end)").font(.caption).foregroundStyle(Theme.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.vertical, 18)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
                Text(holidayFootnote).font(.caption2).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(24)
        }.background(Theme.background).foregroundStyle(Theme.text).navigationTitle("휴무일")
            .sheet(isPresented: $adding) { DayOffEditor(off: DayOff(start: store.engine.dayKey(.now), end: store.engine.dayKey(.now), title: "휴무")) }
            .sheet(item: $edit) { DayOffEditor(off: $0) }
            .confirmationDialog(workChoiceTitle, isPresented: Binding(get: { workChoice != nil }, set: { if !$0 { workChoice = nil } }), titleVisibility: .visible) {
                if let date = workChoice {
                    let key = store.engine.dayKey(date)
                    if store.routine.workDays.contains(key) {
                        Button("출근 취소 · 다시 쉬기") { store.update { $0.workDays.remove(key) } }
                    } else {
                        Button("이날 출근 · 알람과 문자 켜기") { store.update { $0.workDays.insert(key) } }
                    }
                    Button("휴무로 등록") { edit = DayOff(start: key, end: key, title: "휴무") }
                }
            }
    }
    private var holidayFootnote: String {
        let years = KoreanHolidays.coveredYears.sorted()
        let range = years.count > 1 ? "\(years.first!)–\(years.last!)년" : "\(years.first ?? 2026)년"
        let updated = HolidayService.shared.lastUpdated.map { " · \($0.formatted(.dateTime.month().day())) 갱신" } ?? ""
        return "대한민국 공휴일: \(range)\(updated)\n매주 자동으로 갱신해요. 주말·공휴일을 눌러 출근일로 바꿀 수 있어요."
    }
    private var workChoiceTitle: String {
        guard let date = workChoice else { return "" }
        var plain = store.routine; plain.daysOff = []; plain.workDays = []
        return date.formatted(.dateTime.month().day().weekday()) + " · " + (store.engine.reasonOff(date, plain) ?? "근무일")
    }
    private enum DayKind {
        case work, weekend, holiday, personal, extraWork
        var fill: Color {
            switch self {
            case .work, .extraWork: .clear
            case .weekend: Theme.secondary.opacity(0.12)
            case .holiday: Theme.primary.opacity(0.2)
            case .personal: Theme.primary
            }
        }
    }
    // Same precedence as RoutineEngine.reasonOff: personal day off, then holiday, then weekend.
    private func dayKind(_ date: Date) -> DayKind {
        let key = store.engine.dayKey(date), r = store.routine
        if r.daysOff.contains(where: { $0.start <= key && key <= $0.end }) { return .personal }
        if r.workDays.contains(key) { return .extraWork }
        if r.excludeHolidays, KoreanHolidays.name(for: key) != nil { return .holiday }
        if r.excludeWeekends, calendar.isDateInWeekend(date) { return .weekend }
        return .work
    }
    private func legend(_ fill: Color, _ title: String) -> some View {
        HStack(spacing: 6) { RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 14, height: 14); Text(title) }
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
