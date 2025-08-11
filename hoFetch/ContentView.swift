import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioManager()

    var body: some View {
        VStack(spacing: 16) {
            Text("hoFetch 音声録音＋リアルタイム出力")
                .font(.headline)

            Button(action: {
                audio.isRecording ? audio.stopRecording() : audio.startRecording()
            }) {
                Text(audio.isRecording ? "停止" : "録音開始")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(audio.isRecording ? Color.red.opacity(0.85) : Color.green.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Toggle(isOn: Binding(get: { audio.isMonitoring }, set: { _ in audio.toggleMonitoring() })) {
                Text("モニター出力")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("録音: \(audio.isRecording ? "ON" : "OFF")")
                Text("モニター: \(audio.isMonitoring ? "ON" : "OFF")")
                if let url = audio.lastFileURL {
                    Text("保存先: \(url.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let err = audio.errorMessage {
                    Text("エラー: \(err)")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(audio.recordings, id: \.self) { url in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            if audio.currentPlayingURL == url {
                                let current = audio.playbackCurrentTime
                                let duration = max(audio.playbackDuration, 0.001)
                                let progress = current / duration
                                ProgressView(value: progress)
                                    .frame(maxWidth: 160)
                                Text("\(formatTime(current)) / \(formatTime(duration))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(action: {
                            audio.togglePlay(url)
                        }) {
                            Image(systemName: (audio.currentPlayingURL == url && audio.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { audio.recordings[$0] }.forEach { url in
                        audio.deleteRecording(at: url)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            audio.requestPermission()
            audio.reloadRecordings()
        }
    }
}
 
private func formatTime(_ t: TimeInterval) -> String {
    let total = Int(t.rounded())
    let m = total / 60
    let s = total % 60
    return String(format: "%d:%02d", m, s)
}
 
#Preview {
    ContentView()
}
