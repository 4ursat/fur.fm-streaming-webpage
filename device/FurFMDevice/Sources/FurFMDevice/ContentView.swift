import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 0) {
            DeviceListView()

            TabView {
                LevelMeterView()
                    .padding()
                    .tabItem { Label("Meter", systemImage: "waveform") }

                TunerView()
                    .tabItem { Label("Tuner", systemImage: "tuningfork") }

                MetronomeView()
                    .tabItem { Label("Metronome", systemImage: "metronome") }

                RecorderView()
                    .tabItem { Label("Record", systemImage: "record.circle") }
            }
        }
        .onAppear {
            audioEngine.refreshDevices()
            if audioEngine.selectedInputID == nil {
                audioEngine.selectedInputID = audioEngine.inputDevices.first?.id
            }
            try? audioEngine.start()
        }
    }
}
