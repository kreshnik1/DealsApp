import SwiftUI

struct AppThemeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.screenBase,
                    AppTheme.Colors.screenSecondary
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    AppTheme.Colors.screenTintTop,
                    .clear
                ],
                center: .topTrailing,
                startRadius: 16,
                endRadius: 300
            )
            .offset(x: 72, y: -28)

            RadialGradient(
                colors: [
                    AppTheme.Colors.screenTintBottom,
                    .clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 280
            )
            .offset(x: -100, y: 160)
        }
        .ignoresSafeArea()
    }
}
