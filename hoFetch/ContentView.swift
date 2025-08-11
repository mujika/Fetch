import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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

            Spacer()
        }
        .padding()
        .onAppear {
            audio.setModelContext(modelContext)
            audio.requestPermission()
        }
    }
}

#Preview {
    ContentView()
}
