import SwiftUI

struct StoreTintBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.001)

            RadialGradient(
                colors: [
                    color.opacity(0.45),
                    color.opacity(0.18),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 320
            )
            .blur(radius: 30)

            LinearGradient(
                colors: [
                    .black.opacity(0.18),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .compositingGroup()
    }
}

#Preview {
    StoreTintBackground(color: .teal)
}
