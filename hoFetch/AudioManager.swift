import Foundation
import AVFoundation
import Combine

final class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isMonitoring = false
    @Published var lastFileURL: URL?
    @Published var errorMessage: String?
    @Published var permissionGranted = false
    @Published var recordings: [URL] = []
    @Published var isPlaying = false
    @Published var currentPlayingURL: URL?

    @Published var playbackCurrentTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0

    private let audioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private let engine = AVAudioEngine()
    private var player: AVAudioPlayer?
    private var playbackTimer: Timer?


    private let sampleRate: Double = 44100

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        reloadRecordings()
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        audioSession.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                completion?(granted)
            }
        }
    }

    private func configureSessionActive() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true, options: [])
    }
    func reloadRecordings() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urls = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        let audio = urls.filter { $0.pathExtension.lowercased() == "m4a" }
        let sorted = audio.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let r = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return l > r
        }
        recordings = sorted
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.playbackCurrentTime = player.currentTime
            self.playbackDuration = player.duration
        }
        RunLoop.main.add(playbackTimer!, forMode: .common)
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        playbackCurrentTime = 0
        playbackDuration = 0
    }

    func play(_ url: URL) {
        do {
            try configureSessionActive()
            if currentPlayingURL == url, isPlaying {
                stopPlayback()
                return
            }
            stopPlayback()
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            currentPlayingURL = url
            playbackDuration = player?.duration ?? 0
            startPlaybackTimer()
        } catch {
            errorMessage = "再生エラー: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        currentPlayingURL = nil
        stopPlaybackTimer()
        deactivateSessionIfIdle()
    }

    func togglePlay(_ url: URL) {
        if currentPlayingURL == url, isPlaying {
            stopPlayback()
        } else {
            play(url)
        }
    }

    func deleteRecording(at url: URL) {
        if currentPlayingURL == url {
            stopPlayback()
        }
        try? FileManager.default.removeItem(at: url)
        reloadRecordings()
    }


    private func deactivateSessionIfIdle() {
        if !isRecording && !isMonitoring {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func startRecording() {
        let start: () -> Void = { [weak self] in
            guard let self = self else { return }
            do {
                try self.configureSessionActive()
                let url = self.newRecordingURL()
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: self.sampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                self.recorder = try AVAudioRecorder(url: url, settings: settings)
                self.recorder?.delegate = self
                self.recorder?.isMeteringEnabled = true
                if self.recorder?.record() == true {
                    self.isRecording = true
                    self.lastFileURL = url
                    self.reloadRecordings()
                } else {
                    self.errorMessage = "録音開始に失敗しました。"
                }
            } catch {
                self.errorMessage = "初期化エラー: \(error.localizedDescription)"
            }
        }

        if permissionGranted {
            start()
        } else {
            requestPermission { granted in
                if granted {
                    start()
                } else {
                    self.errorMessage = "マイクへのアクセスが許可されていません。"
                }
            }
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        reloadRecordings()
        deactivateSessionIfIdle()
    }

    func startMonitoring() {
        let start: () -> Void = { [weak self] in
            guard let self = self else { return }
            do {
                try self.configureSessionActive()
                let input = self.engine.inputNode
                let mainMixer = self.engine.mainMixerNode
                let inputFormat = input.inputFormat(forBus: 0)
                self.engine.disconnectNodeOutput(input)
                self.engine.connect(input, to: mainMixer, format: inputFormat)
                if !self.engine.isRunning {
                    try self.engine.start()
                }
                self.isMonitoring = true
            } catch {
                self.errorMessage = "モニター開始エラー: \(error.localizedDescription)"
            }
        }

        if permissionGranted {
            start()
        } else {
            requestPermission { granted in
                if granted {
                    start()
                } else {
                    self.errorMessage = "マイクへのアクセスが許可されていません。"
                }
            }
        }
    }

    func stopMonitoring() {
        engine.pause()
        engine.stop()
        engine.reset()
        isMonitoring = false
        deactivateSessionIfIdle()
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    private func newRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "rec_\(formatter.string(from: Date())).m4a"
        return docs.appendingPathComponent(name)
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            if isRecording {
                recorder?.pause()
            }
            if engine.isRunning {
                engine.pause()
            }
        case .ended:
            break
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawReason = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        if reason == .oldDeviceUnavailable {
            if isMonitoring {
                stopMonitoring()
            }
        }
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "エンコードエラー: \(error?.localizedDescription ?? "不明")"
        }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        errorMessage = "デコードエラー: \(error?.localizedDescription ?? "不明")"
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentPlayingURL = nil
        stopPlaybackTimer()
        deactivateSessionIfIdle()
    }
}
