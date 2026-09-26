import SwiftUI
import ScrambleKit

struct ContentView: View {
    private let scrambler = Scrambler()
    @State private var scramble: Scramble?

    var body: some View {
        VStack(spacing: 32) {
            Text(scramble?.description ?? " ")
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .onTapGesture { scramble = scrambler.randomScramble() }
            Text("0.00")
                .font(.system(size: 96, weight: .light, design: .monospaced))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { scramble = scrambler.randomScramble() }
    }
}

#Preview {
    ContentView()
}
