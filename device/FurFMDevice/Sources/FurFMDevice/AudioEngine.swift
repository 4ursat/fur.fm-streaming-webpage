import Accelerate
import AudioToolbox
import AVFoundation
import CoreAudio

final class AudioEngine: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var selectedInputID: AudioDeviceID?
    @Published var peakLevel: Float = 0
    @Published var rmsLevel: Float = 0
    @Published var isRunning = false
    @Published var detectedFrequency: Float?
    @Published var lastError: String?

    let recorder = Recorder()
    let engine = AVAudioEngine()

    private var pitchDetector: PitchDetector?
    private var pitchSampleBuffer: [Float] = []
    private let pitchWindowSize = 2048

    func refreshDevices() {
        inputDevices = AudioDeviceManager.inputDevices()
    }

    func selectInput(_ device: AudioDevice) {
        do {
            try setHardwareInputDevice(device.id)
            selectedInputID = device.id
        } catch {
            lastError = "Couldn't switch input device: \(error.localizedDescription)"
        }
    }

    func start() throws {
        guard !isRunning else { return }
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        pitchDetector = PitchDetector(sampleRate: format.sampleRate)
        pitchSampleBuffer.removeAll(keepingCapacity: true)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
        lastError = nil
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        peakLevel = 0
        rmsLevel = 0
        detectedFrequency = nil
    }

    func startRecording() throws {
        let format = engine.inputNode.outputFormat(forBus: 0)
        try recorder.start(format: format)
    }

    func stopRecording() {
        recorder.stop()
    }

    // MARK: - Tap processing (background thread)

    private func process(buffer: AVAudioPCMBuffer) {
        let (peak, rms) = Self.computeLevels(buffer)

        if recorder.isRecording {
            recorder.write(buffer)
        }

        var newFrequency: Float?
        var frequencyChanged = false
        if let window = collectPitchWindow(buffer) {
            newFrequency = pitchDetector?.detectPitch(window)
            frequencyChanged = true
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.peakLevel = peak
            self.rmsLevel = rms
            if frequencyChanged {
                self.detectedFrequency = newFrequency
            }
        }
    }

    /// Accumulates tap buffers until a full pitch-detection window is available.
    private func collectPitchWindow(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        pitchSampleBuffer.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameLength))
        guard pitchSampleBuffer.count >= pitchWindowSize else { return nil }

        let window = Array(pitchSampleBuffer.suffix(pitchWindowSize))
        pitchSampleBuffer.removeAll(keepingCapacity: true)
        return window
    }

    private func setHardwareInputDevice(_ deviceID: AudioDeviceID) throws {
        let wasRunning = isRunning
        if wasRunning { stop() }

        guard let audioUnit = engine.inputNode.audioUnit else {
            throw NSError(domain: "FurFMDevice", code: 1, userInfo: [NSLocalizedDescriptionKey: "No underlying audio unit"])
        }
        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw NSError(domain: "FurFMDevice", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "CoreAudio error \(status)"])
        }

        if wasRunning { try start() }
    }

    private static func computeLevels(_ buffer: AVAudioPCMBuffer) -> (peak: Float, rms: Float) {
        guard let channelData = buffer.floatChannelData else { return (0, 0) }
        let frameLength = vDSP_Length(buffer.frameLength)
        guard frameLength > 0 else { return (0, 0) }
        let channelCount = Int(buffer.format.channelCount)

        var peak: Float = 0
        var rmsSum: Float = 0
        for ch in 0..<channelCount {
            let data = channelData[ch]
            var channelPeak: Float = 0
            vDSP_maxmgv(data, 1, &channelPeak, frameLength)
            peak = max(peak, channelPeak)
            var meanSquare: Float = 0
            vDSP_measqv(data, 1, &meanSquare, frameLength)
            rmsSum += meanSquare
        }
        let rms = sqrt(rmsSum / Float(channelCount))
        return (peak, rms)
    }
}
