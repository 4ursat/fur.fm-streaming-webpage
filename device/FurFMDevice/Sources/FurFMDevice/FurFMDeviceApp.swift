import SwiftUI

@main
struct FurFMDeviceApp: App {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var metronome = MetronomeEngine()

    var body: some Scene {
        WindowGroup("Fur FM — Device") {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(audioEngine.recorder)
                .environmentObject(metronome)
                .frame(minWidth: 480, minHeight: 420)
        }
        .windowResizability(.contentSize)
    }
}
