import SwiftUI

struct LevelMeterView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            meterRow(label: "PEAK", value: audioEngine.peakLevel)
            meterRow(label: "RMS", value: audioEngine.rmsLevel)
        }
    }

    private func meterRow(label: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.25))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(meterColor(for: value))
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                        .animation(.linear(duration: 0.05), value: value)
                }
            }
            .frame(height: 20)
        }
    }

    private func meterColor(for value: Float) -> Color {
        if value > 0.9 { return .red }
        if value > 0.7 { return .yellow }
        return .green
    }
}
