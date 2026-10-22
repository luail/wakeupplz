import SwiftUI

struct VerificationView: View {
    @Environment(RoutineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var attempts: [String] = []
    @State private var wrong = false
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Text(Date.now.formatted(.dateTime.month().day().weekday())).font(.caption).foregroundStyle(Theme.secondary)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sun.max").font(.title2).foregroundStyle(Theme.primary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("좋은 아침이에요.")
                            Text("일어났다면 아래 문구를 정확히 입력해주세요.").foregroundStyle(Theme.secondary)
                            Text(store.routine.phrase).fontWeight(.semibold).textSelection(.disabled)
                        }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20)); Spacer(minLength: 0)
                    }
                    ForEach(Array(attempts.enumerated()), id: \.offset) { _, attempt in
                        HStack { Spacer(minLength: 40); Text(attempt).padding(18).foregroundStyle(.white).background(Theme.primary, in: RoundedRectangle(cornerRadius: 20)) }
                    }
                    if store.verifiedToday {
                        Label("기상 인증이 완료됐어요.\n오늘 남은 알람과 문자 예약을 취소해요.", systemImage: "checkmark.circle.fill").font(.subheadline).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20)).accessibilityIdentifier("verification.success")
                        #if DEBUG
                        Button("오늘 인증 초기화 (테스트용)") { store.resetToday(); attempts = [] }.font(.footnote).foregroundStyle(Theme.secondary)
                        #endif
                    }
                    if wrong { Text("문구가 일치하지 않아요. 띄어쓰기와 느낌표도 확인해주세요.").font(.caption).foregroundStyle(.red).accessibilityIdentifier("verification.error") }
                }.padding(24)
            }
            if !store.verifiedToday {
                HStack {
                    TextField("인증 문구를 입력하세요", text: $text).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.send).onSubmit(send).accessibilityIdentifier("verification.input")
                    Button(action: send) { Image(systemName: "paperplane.fill").frame(width: 44, height: 44).foregroundStyle(.white).background(Theme.primary, in: Circle()) }.disabled(text.isEmpty).accessibilityLabel("인증 문구 전송")
                }.padding(8).padding(.leading, 12).background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.border)).padding(20)
            }
        }.background(Theme.background).foregroundStyle(Theme.text).navigationTitle("기상 인증").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
    }
    private func send() {
        guard !text.isEmpty else { return }; attempts.append(text)
        wrong = text != store.routine.phrase
        if !wrong { _ = store.verify(text) }
        text = ""
    }
}
