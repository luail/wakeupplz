import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SoundsView: View {
    @Environment(RoutineStore.self) private var store
    @State private var importing = false
    @State private var player: AVAudioPlayer?
    @State private var playing: String?
    @State private var previewFinishTask: Task<Void, Never>?
    @State private var custom: [String] = []
    private let builtins = ["Morning Bell.wav", "Soft Chime.wav", "Classic Alarm.wav"]
    private var soundsFolder: URL { URL.libraryDirectory.appending(path: "Sounds") }
    var body: some View {
        List {
            Section("알람음") {
                ForEach(builtins + custom, id: \.self) { name in
                    HStack(spacing: 14) {
                        Button { store.update { $0.sound = name } } label: {
                            HStack(spacing: 14) {
                                Image(systemName: store.routine.sound == name ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Theme.primary)
                                Text(URL(filePath: name).deletingPathExtension().lastPathComponent).foregroundStyle(Theme.text)
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button { preview(name) } label: { Image(systemName: playing == name ? "stop.fill" : "play.fill").frame(width: 44, height: 44) }.buttonStyle(.borderless).accessibilityLabel("\(name) 미리 듣기")
                    }
                }
            }.listRowBackground(Theme.surface)
            Section {
                Button { importing = true } label: { Label("개인 음악 파일 가져오기", systemImage: "square.and.arrow.down") }
            } footer: { Text("30초 이하의 오디오 파일을 가져올 수 있어요. 알람용 CAF 파일로 기기 안에 복사합니다. 보호된 스트리밍 음악은 사용할 수 없어요.") }
            Section { Text("미리 듣기는 현재 기기의 음량으로 재생됩니다. 알람의 실제 출력과 잠금 상태 동작은 iPhone에서 확인해주세요.").font(.footnote).foregroundStyle(Theme.secondary) }.listRowBackground(Theme.surface)
        }.appForm().navigationTitle("알람 사운드").navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: reload)
            .onDisappear { previewFinishTask?.cancel(); player?.stop(); playing = nil }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
                do { try importSound(result.get()) } catch { store.error = "파일을 가져오지 못했어요. \(error.localizedDescription)" }
            }
    }
    private func reload() {
        custom = ((try? FileManager.default.contentsOfDirectory(atPath: soundsFolder.path)) ?? []).filter { $0.hasSuffix(".caf") }.sorted()
    }
    private func preview(_ name: String) {
        previewFinishTask?.cancel()
        if playing == name && player?.isPlaying == true { player?.stop(); playing = nil; return }
        do {
            player?.stop()
            let url = builtins.contains(name) ? Bundle.main.url(forResource: name, withExtension: nil)! : soundsFolder.appending(path: name)
            player = try AVAudioPlayer(contentsOf: url)
            guard player?.play() == true else { throw SoundError.unreadable }
            playing = name
            let duration = player?.duration ?? 0
            previewFinishTask = Task {
                do { try await Task.sleep(for: .seconds(duration + 0.1)) } catch { return }
                playing = nil
            }
        } catch { playing = nil; store.error = error.localizedDescription }
    }
    private func importSound(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let input = try AVAudioFile(forReading: url)
        let duration = Double(input.length) / input.processingFormat.sampleRate
        guard duration > 0, duration <= 30, input.processingFormat.channelCount <= 2, input.processingFormat.sampleRate <= 192000 else { throw SoundError.duration }
        try FileManager.default.createDirectory(at: soundsFolder, withIntermediateDirectories: true)
        let safeName = url.deletingPathExtension().lastPathComponent.prefix(40).replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeName)-\(UUID().uuidString.prefix(6)).caf"
        let destination = soundsFolder.appending(path: filename)
        do {
            let output = try AVAudioFile(forWriting: destination, settings: input.processingFormat.settings)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: 8192) else { throw SoundError.unreadable }
            while input.framePosition < input.length { try input.read(into: buffer); try output.write(from: buffer) }
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
        reload()
        store.update { $0.sound = filename }
    }
}
private enum SoundError: LocalizedError {
    case duration, unreadable
    var errorDescription: String? { self == .duration ? "30초 이하, 2채널 이하의 오디오를 선택해주세요." : "오디오를 재생할 수 없어요." }
}
