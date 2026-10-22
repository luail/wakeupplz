import Foundation
import UserNotifications

// Free Personal Team builds stop launching when the embedded profile expires (7 days).
// The Mac renews automatically (scripts/auto-renew.sh); this is the on-phone fallback warning.
enum SigningExpiry {
    static let notificationID = "signing-expiry"
    static let date: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }()
    static func scheduleWarning() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        guard let date, await center.notificationSettings().authorizationStatus == .authorized else { return }
        let fire = date.addingTimeInterval(-24 * 3600)
        guard fire > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "WakeUpPlz 서명이 곧 만료돼요"
        content.body = "24시간 뒤 앱이 실행되지 않아 알람이 울리지 않을 수 있어요. iPhone을 Mac에 연결하거나 같은 Wi-Fi에서 잠금 해제해주세요."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSinceNow, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }
}
