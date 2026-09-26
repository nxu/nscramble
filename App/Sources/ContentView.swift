import SwiftUI
import ScrambleKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("scramble goes here")
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("0.00")
                .font(.system(size: 96, weight: .light, design: .monospaced))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
