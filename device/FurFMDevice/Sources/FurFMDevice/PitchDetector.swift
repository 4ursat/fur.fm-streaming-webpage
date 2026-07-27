import Accelerate
import Foundation

final class PitchDetector {
    let sampleRate: Double
    private let minFrequency: Double = 60
    private let maxFrequency: Double = 1500
    private let silenceThreshold: Float = 0.00003
    private let confidenceThreshold: Float = 0.35

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Normalized autocorrelation pitch detection over a mono sample window.
    func detectPitch(_ samples: [Float]) -> Float? {
        let minLag = max(1, Int(sampleRate / maxFrequency))
        let maxLag = Int(sampleRate / minFrequency)
        guard samples.count > maxLag + 8 else { return nil }

        var totalEnergy: Float = 0
        vDSP_measqv(samples, 1, &totalEnergy, vDSP_Length(samples.count))
        guard totalEnergy > silenceThreshold else { return nil }

        var bestLag = -1
        var bestScore: Float = 0

        samples.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            for lag in minLag...maxLag {
                let count = samples.count - lag
                guard count > 0 else { break }
                var sum: Float = 0
                var e1: Float = 0
                var e2: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &sum, vDSP_Length(count))
                vDSP_measqv(base, 1, &e1, vDSP_Length(count))
                vDSP_measqv(base + lag, 1, &e2, vDSP_Length(count))
                let denom = (e1 * e2).squareRoot() * Float(count)
                guard denom > 0 else { continue }
                let score = sum / denom
                if score > bestScore {
                    bestScore = score
                    bestLag = lag
                }
            }
        }

        guard bestLag > 0, bestScore > confidenceThreshold else { return nil }
        return Float(sampleRate) / Float(bestLag)
    }
}

struct NoteInfo {
    let name: String
    let octave: Int
    let cents: Float
}

enum NoteMath {
    static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func noteInfo(forFrequency freq: Float) -> NoteInfo {
        let midi = 69 + 12 * log2(freq / 440.0)
        let roundedMidi = midi.rounded()
        let cents = (midi - roundedMidi) * 100
        let noteIndex = ((Int(roundedMidi) % 12) + 12) % 12
        let octave = Int(roundedMidi) / 12 - 1
        return NoteInfo(name: names[noteIndex], octave: octave, cents: cents)
    }
}
