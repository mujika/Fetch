import Foundation
import AVFoundation
import Combine

final class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isMonitoring = false
    @Published var lastFileURL: URL?
    @Published var errorMessage: String?
    @Published var permissionGranted = false

    private let audioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private let engine = AVAudioEngine()

    private let sampleRate: Double = 44100

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
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
