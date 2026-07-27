import AVFoundation
import Foundation

final class Recorder: ObservableObject {
    @Published var isRecording = false
    @Published var lastFileURL: URL?
    @Published var elapsedSeconds: TimeInterval = 0

    private var audioFile: AVAudioFile?
    private var startTime: Date?
    private var timer: Timer?

    func start(format: AVAudioFormat) throws {
        guard !isRecording else { return }
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music")
        let dir = musicDir.appendingPathComponent("Fur FM Device", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(Self.timestampedFilename())
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        lastFileURL = url
        startTime = Date()
        elapsedSeconds = 0
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.elapsedSeconds = Date().timeIntervalSince(start)
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate()
        timer = nil
        audioFile = nil
    }

    /// Called from the shared audio tap callback (background thread).
    func write(_ buffer: AVAudioPCMBuffer) {
        guard isRecording, let audioFile else { return }
        try? audioFile.write(from: buffer)
    }

    private static func timestampedFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "recording-\(formatter.string(from: Date())).caf"
    }
}
