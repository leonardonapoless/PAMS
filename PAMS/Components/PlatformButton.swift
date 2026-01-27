import SwiftUI
import UIKit

enum PlatformIcon {
    case system(String)
    case asset(String)
    
    @ViewBuilder
    func view(size: CGFloat) -> some View {
        switch self {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.9, weight: .semibold))
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        }
    }
}

struct PlatformButtonStack: View {
    enum CopyState { case idle, success, failed }
    
    let icon: PlatformIcon
    var size: CGFloat = 44
    var iconScale: CGFloat = 1.0
    var iconOffset: CGSize = .zero
    var link: PlatformLink?
    var accessibilityLabel: String?
    let action: () -> Void
    
    private var innerIconSize: CGFloat { size * 0.6 }
    private var effectiveIconSize: CGFloat { innerIconSize * iconScale }
    @Environment(\.colorScheme) private var colorScheme
    @State private var copyState: CopyState = .idle
    
    private var copyableLink: String? {
        link?.webUrl
    }
    
    private var hasValidCopyLink: Bool {
        guard let url = copyableLink else { return false }
        return !url.isEmpty
    }
    
    private var hasValidPlatformLink: Bool {
        guard let link else { return false }
        let hasNative = link.nativeUrl != nil && !link.nativeUrl!.isEmpty
        let hasWeb = link.webUrl != nil && !link.webUrl!.isEmpty
        return hasNative || hasWeb
    }
    
    private var copyIcon: String {
        switch copyState {
        case .idle: return "link"
        case .success: return "checkmark"
        case .failed: return "xmark"
        }
    }
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                Button {
                    guard let url = copyableLink, !url.isEmpty else { return }
                    UIPasteboard.general.string = url
                    if UIPasteboard.general.string == url {
                        copyState = .success
                    } else {
                        copyState = .failed
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copyState = .idle
                    }
                } label: {
                    Image(systemName: copyIcon)
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: effectiveIconSize * 0.7, weight: .semibold))
                        .frame(width: effectiveIconSize, height: effectiveIconSize)
                }
                .compositingGroup()
                .frame(width: size, height: size)
                .buttonStyle(.glass)
                .disabled(!hasValidCopyLink)
                .opacity(hasValidCopyLink ? 1 : 0.5)
                .accessibilityLabel("Copy link")
                .sensoryFeedback(.success, trigger: copyState == .success)
                .sensoryFeedback(.error, trigger: copyState == .failed)
                
                Button(action: action) {
                    icon.view(size: effectiveIconSize)
                        .frame(width: effectiveIconSize, height: effectiveIconSize)
                        .offset(iconOffset)
                        .opacity(hasValidPlatformLink ? 1 : 0.4)
                }
                .compositingGroup()
                .frame(width: size, height: size)
                .buttonStyle(.glass)
                .disabled(!hasValidPlatformLink)
                .accessibilityLabel(accessibilityLabel ?? "")
            }
        }
        .shadow(color: colorScheme == .dark ? .white.opacity(0.03) : .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewContainer: View {
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    CoverArtCard(isFocused: true) {
                        AsyncImage(url: URL(string: "https://f4.bcbits.com/img/a0190578456_10.jpg")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure:
                                Color.secondary.opacity(0.1)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Color.secondary.opacity(0.1)
                            }
                        }
                    } back: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Release Date: 1987")
                            Divider()
                            Text("Album: Hot Paradox")
                            Divider()
                            Text("Genre: Coldwave")
                            Divider()
                            Text("Label: Minimal Wave")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(.systemGray6))
                    }
                    .frame(width: 280, height: 280)
                    
                    VStack(spacing: 4) {
                        Text("Inside Out")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Martin Dupont")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 18) {
                        PlatformButtonStack(
                            icon: .system("applelogo"),
                            size: 44,
                            link: nil
                        ) {}
                        
                        PlatformButtonStack(
                            icon: .asset(colorScheme == .dark ? "spotify_icon_white" : "spotify_icon_black"),
                            size: 44,
                            link: PlatformLink(webUrl: "https://open.spotify.com/track/1tbL1iLdlz8fLqopGAL6zZ", nativeUrl: nil)
                        ) {}
                        
                        PlatformButtonStack(
                            icon: .asset(colorScheme == .dark ? "tidal_icon_white" : "tidal_icon_black"),
                            size: 44,
                            link: nil
                        ) {}
                        
                        PlatformButtonStack(
                            icon: .asset(colorScheme == .dark ? "yt_icon_white" : "yt_icon_black"),
                            size: 44,
                            link: PlatformLink(webUrl: "https://www.youtube.com/watch?v=jNNmVp0gd5Q", nativeUrl: nil)
                        ) {}
                    }
                }
                .padding(.vertical, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
    return PreviewContainer()
}
