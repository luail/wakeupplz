import SwiftUI

enum Theme {
    static let primary = adaptive(0x5B6770, 0x8B7355)
    static let background = adaptive(0xF8F9FA, 0x1A1816)
    static let surface = adaptive(0xFFFFFF, 0x24221F)
    static let text = adaptive(0x1A1D21, 0xF5F4F2)
    static let secondary = adaptive(0x6B7280, 0xA8A29E)
    static let border = adaptive(0xE5E7EB, 0x3B3732)
    /// Warm sand from the app icon's sun; marks holidays so they differ from gray weekends.
    static let accent = adaptive(0xA0794F, 0xD4AE84)
    private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, alpha: 1)
        })
    }
}
struct PrimaryButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.body.weight(.semibold))
            }.frame(maxWidth: .infinity).padding(.vertical, 17)
        }.buttonStyle(.plain).foregroundStyle(.white).background(Theme.primary, in: RoundedRectangle(cornerRadius: 16))
    }
}
extension View {
    func appForm() -> some View {
        scrollContentBackground(.hidden).background(Theme.background).foregroundStyle(Theme.text)
    }
}
