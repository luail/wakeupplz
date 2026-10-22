import AppIntents
import Foundation

struct RetryAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "기상 미인증 알람 다시 예약"
    static let isDiscoverable = false
    @Parameter(title: "날짜") var day: String
    init() {}
    init(day: String) { self.day = day }
    @MainActor func perform() async throws -> some IntentResult {
        try await ScheduleService.shared.retryIfNeeded(day: day)
        return .result()
    }
}
struct PendingMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "WakeUpPlz 미인증 발송 요청 가져오기"
    static let description = IntentDescription("현재 1분 회차가 도래했고 미인증일 때만 JSON을 한 번 반환합니다. 자체적으로 문자를 보내지 않습니다. 요청이 없으면 빈 문자열을 반환합니다.")
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let payload = RoutineStore.shared.claimMessage() else { return .result(value: "") }
        return .result(value: String(decoding: try JSONEncoder().encode(payload), as: UTF8.self))
    }
}
