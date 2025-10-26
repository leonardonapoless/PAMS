import SwiftUI

struct PlatformButton: View {
    enum Icon { case system(String), asset(String) }

    let icon: Icon
    var size: CGFloat = 44
    var iconScale: CGFloat = 1.0
    var iconOffset: CGSize = .zero
    var accessibilityLabel: String?
    let action: () -> Void

    private var innerIconSize: CGFloat { size * 0.6 }
    private var effectiveIconSize: CGFloat { innerIconSize * iconScale }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            iconView
                .frame(width: effectiveIconSize, height: effectiveIconSize)
                .offset(iconOffset)
        }
        .frame(width: size, height: size)
        .buttonStyle(.glass)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.02) : .black.opacity(0.05), radius: 1.2, x: 0, y: 1)
        .accessibilityLabel(accessibilityLabel ?? "")
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: effectiveIconSize * 0.9, weight: .semibold))
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        }
    }
}
