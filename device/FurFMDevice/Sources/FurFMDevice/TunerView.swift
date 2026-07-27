import SwiftUI

struct TunerView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 24) {
            if let freq = audioEngine.detectedFrequency {
                let info = NoteMath.noteInfo(forFrequency: freq)
                Text(info.name + String(info.octave))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text(String(format: "%.1f Hz  ·  %+.0f cents", freq, info.cents))
                    .foregroundStyle(.secondary)
                CentsGaugeView(cents: info.cents)
                    .frame(height: 40)
                    .padding(.horizontal, 40)
            } else {
                Text("—")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("Play or sing a note")
                    .foregroundStyle(.secondary)
                CentsGaugeView(cents: 0)
                    .frame(height: 40)
                    .padding(.horizontal, 40)
                    .opacity(0.2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CentsGaugeView: View {
    let cents: Float

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = max(-50, min(50, cents))
            let travel = width / 2 - 10
            let indicatorX = width / 2 + CGFloat(clamped / 50) * travel

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.25))
                    .frame(height: 6)

                Rectangle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 2, height: 16)

                Circle()
                    .fill(abs(clamped) < 5 ? Color.green : Color.orange)
                    .frame(width: 16, height: 16)
                    .position(x: indicatorX, y: geo.size.height / 2)
                    .animation(.easeOut(duration: 0.1), value: cents)
            }
            .frame(width: width, height: geo.size.height)
        }
    }
}
