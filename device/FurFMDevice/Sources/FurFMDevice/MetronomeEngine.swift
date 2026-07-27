import AVFoundation
import Foundation

/// Runs on its own dedicated AVAudioEngine so it's independent of the input-monitoring engine.
final class MetronomeEngine: ObservableObject {
    @Published var bpm: Double = 120 {
        didSet {
            if isPlaying { restart() }
        }
    }
    @Published var beatsPerBar: Int = 4
    @Published var isPlaying = false
    @Published var currentBeat: Int = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var clickBuffer: AVAudioPCMBuffer!
    private var accentBuffer: AVAudioPCMBuffer!
    private var nextBeatSampleTime: AVAudioTime?
    private var scheduledBeats = 0
    private var playedBeats = 0
    private let lookaheadBeats = 8

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        clickBuffer = Self.makeClick(format: format, frequency: 1000, accent: false)
        accentBuffer = Self.makeClick(format: format, frequency: 1600, accent: true)
    }

    func start() {
        guard !isPlaying else { return }
        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            return
        }
        isPlaying = true
        scheduledBeats = 0
        playedBeats = 0
        nextBeatSampleTime = nil
        currentBeat = 0
        player.play()
        scheduleAhead()
    }

    func stop() {
        isPlaying = false
        player.stop()
        nextBeatSampleTime = nil
    }

    private func restart() {
        stop()
        start()
    }

    private func scheduleAhead() {
        guard isPlaying else { return }
        let sampleRate = format.sampleRate
        let samplesPerBeat = AVAudioFramePosition((60.0 / bpm) * sampleRate)

        while scheduledBeats - playedBeats < lookaheadBeats {
            let beatIndex = scheduledBeats
            let buffer = (beatIndex % beatsPerBar == 0) ? accentBuffer! : clickBuffer!

            let startTime: AVAudioTime
            if let nextTime = nextBeatSampleTime {
                startTime = nextTime
            } else if let lastRenderTime = player.lastRenderTime,
                      let playerTime = player.playerTime(forNodeTime: lastRenderTime) {
                startTime = AVAudioTime(sampleTime: playerTime.sampleTime + Int64(sampleRate * 0.1), atRate: sampleRate)
            } else {
                // engine not ready yet; try again shortly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.scheduleAhead()
                }
                return
            }

            player.scheduleBuffer(buffer, at: startTime, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.isPlaying else { return }
                    self.currentBeat = beatIndex % self.beatsPerBar
                    self.playedBeats += 1
                    self.scheduleAhead()
                }
            }

            nextBeatSampleTime = AVAudioTime(sampleTime: startTime.sampleTime + samplesPerBeat, atRate: sampleRate)
            scheduledBeats += 1
        }
    }

    private static func makeClick(format: AVAudioFormat, frequency: Float, accent: Bool) -> AVAudioPCMBuffer {
        let durationSeconds: Double = 0.03
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let amplitude: Float = accent ? 0.9 : 0.6

        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(sampleRate)
            let envelope = exp(-t * 80)
            let sample = sin(2 * Float.pi * frequency * t) * envelope * amplitude
            for ch in 0..<Int(format.channelCount) {
                buffer.floatChannelData![ch][frame] = sample
            }
        }
        return buffer
    }
}
