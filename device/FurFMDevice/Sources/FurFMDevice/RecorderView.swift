import AppKit
import SwiftUI

struct RecorderView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var recorder: Recorder

    var body: some View {
        VStack(spacing: 20) {
            Text(formattedTime(recorder.elapsedSeconds))
                .font(.system(size: 40, weight: .bold, design: .monospaced))

            Button(recorder.isRecording ? "Stop Recording" : "Start Recording") {
                if recorder.isRecording {
                    audioEngine.stopRecording()
                } else {
                    try? audioEngine.startRecording()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.isRecording ? .red : .accentColor)

            if let url = recorder.lastFileURL {
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.link)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
