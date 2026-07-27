import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Input").font(.caption).foregroundStyle(.secondary)

                Picker("Input", selection: Binding(
                    get: { audioEngine.selectedInputID ?? audioEngine.inputDevices.first?.id ?? 0 },
                    set: { newID in
                        if let device = audioEngine.inputDevices.first(where: { $0.id == newID }) {
                            audioEngine.selectInput(device)
                        }
                    }
                )) {
                    ForEach(audioEngine.inputDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .labelsHidden()

                Spacer()

                Circle()
                    .fill(audioEngine.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                if !audioEngine.isRunning {
                    Button("Enable") {
                        try? audioEngine.start()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            if let error = audioEngine.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}
