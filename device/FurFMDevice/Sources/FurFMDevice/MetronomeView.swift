import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject var metronome: MetronomeEngine

    var body: some View {
        VStack(spacing: 24) {
            Text("\(Int(metronome.bpm)) BPM")
                .font(.system(size: 40, weight: .bold, design: .rounded))

            Slider(value: $metronome.bpm, in: 30...300, step: 1)
                .frame(maxWidth: 300)

            HStack(spacing: 16) {
                ForEach(0..<metronome.beatsPerBar, id: \.self) { beat in
                    Circle()
                        .fill(metronome.isPlaying && metronome.currentBeat == beat ? Color.orange : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                }
            }

            Stepper("Beats per bar: \(metronome.beatsPerBar)", value: $metronome.beatsPerBar, in: 1...12)
                .frame(maxWidth: 240)

            Button(metronome.isPlaying ? "Stop" : "Start") {
                if metronome.isPlaying {
                    metronome.stop()
                } else {
                    metronome.start()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
