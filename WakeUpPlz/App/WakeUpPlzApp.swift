import SwiftUI

@main struct WakeUpPlzApp: App {
    @State private var store = RoutineStore.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
                .tint(Theme.primary)
                .preferredColorScheme(store.routine.appearance == "system" ? nil : store.routine.appearance == "dark" ? .dark : .light)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .environment(\.timeZone, TimeZone(identifier: "Asia/Seoul")!)
                .task { store.refreshSchedules() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshSchedules() } }
                .alert("확인이 필요해요", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("확인") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
private struct RootView: View {
    var body: some View {
        TabView {
            Tab("홈", systemImage: "sunrise") { NavigationStack { HomeView() } }
            Tab("휴무일", systemImage: "calendar") { NavigationStack { DaysOffView() } }
            Tab("설정", systemImage: "slider.horizontal.3") { NavigationStack { SettingsView() } }
        }
    }
}
