import SwiftUI
import UIKit

struct SearchResultRow: View {
    let item: SearchResultItem
    let isFocused: Bool
    let listFrame: CGRect
    
    let iconSpotifyBlack: String
    let iconSpotifyWhite: String
    let iconTidalBlack: String
    let iconTidalWhite: String
    let iconYTWhite: String
    let iconYTBlack: String

    var body: some View {
        switch item {
        case .track(let track):
            MediaResultRow(
                id: track.id,
                title: track.title,
                subtitle: track.artist,
                artworkURL: track.artworkURL,
                links: track.links,
                isLoading: track.isLoading,
                metadata: [
                    ("Release Date", track.releaseDate),
                    ("Album", track.album),
                    ("Genre", track.genre),
                    ("Duration", track.duration),
                    ("Label", track.recordLabel),
                    ("©", track.copyright)
                ],
                isFocused: isFocused,
                listFrame: listFrame,
                iconConfig: iconConfig,
                showAlbumBadge: false
            )
        case .album(let album):
            MediaResultRow(
                id: album.id,
                title: album.title,
                subtitle: album.artist,
                artworkURL: album.artworkURL,
                links: album.links,
                isLoading: album.isLoading,
                metadata: [
                    ("Release Date", album.releaseDate),
                    ("Genre", album.genre),
                    ("", album.totalTracks), 
                    ("Label", album.recordLabel),
                    ("©", album.copyright)
                ],
                isFocused: isFocused,
                listFrame: listFrame,
                iconConfig: iconConfig,
                showAlbumBadge: true
            )
        }
    }
    
    private var iconConfig: MediaResultRow.IconConfig {
        MediaResultRow.IconConfig(
            spotifyBlack: iconSpotifyBlack,
            spotifyWhite: iconSpotifyWhite,
            tidalBlack: iconTidalBlack,
            tidalWhite: iconTidalWhite,
            ytWhite: iconYTWhite,
            ytBlack: iconYTBlack
        )
    }
}

struct MediaResultRow: View {
    struct IconConfig {
        let spotifyBlack: String
        let spotifyWhite: String
        let tidalBlack: String
        let tidalWhite: String
        let ytWhite: String
        let ytBlack: String
    }
    
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let links: PlatformLinks
    let isLoading: Bool
    let metadata: [(String, String)]
    let isFocused: Bool
    let listFrame: CGRect
    let iconConfig: IconConfig
    let showAlbumBadge: Bool
    
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            CoverArtCard(isFocused: isFocused) {
                if let url = artworkURL {
                    AsyncImage(url: url) { phase in
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
                } else {
                    Color.secondary.opacity(0.1)
                }

            } back: {

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(metadata, id: \.0) { key, value in
                        if !value.isEmpty && value != "n/a" {
                            if key == "©" || key.isEmpty {
                                Text(value)
                            } else {
                                Text("\(key): \(value)")
                            }
                            Divider()
                        }
                    }
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemGray6))
            } badge: {
                if showAlbumBadge {
                    AlbumBadgeView()
                }
            }
            .frame(width: 280, height: 280)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            
            HStack(spacing: 18) {
                PlatformButton(icon: .system("applelogo"), size: 44) {
                    open(link: links.apple)
                }
                PlatformButton(icon: .asset(colorScheme == .dark ? iconConfig.spotifyWhite : iconConfig.spotifyBlack), size: 44) {
                    open(link: links.spotify)
                }
                PlatformButton(icon: .asset(colorScheme == .dark ? iconConfig.tidalWhite : iconConfig.tidalBlack), size: 44) {
                    open(link: links.tidal)
                }
                PlatformButton(icon: .asset(colorScheme == .dark ? iconConfig.ytWhite : iconConfig.ytBlack), size: 44) {
                    open(link: links.youtube)
                }
            }
            .font(.title3)
            .opacity(isLoading ? 0.4 : 1)
            .allowsHitTesting(!isLoading)
            .animation(.easeInOut(duration: 0.3), value: isLoading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: VisibilityPreferenceKey.self,
                        value: [id: calculateVisibility(geometry: geometry)]
                    )
            }
        }
    }
    
    func open(link: PlatformLink?) {
        guard let link else { return }

        if let nativeUrlString = link.nativeUrl,
           let nativeUrl = URL(string: nativeUrlString),
           UIApplication.shared.canOpenURL(nativeUrl) {
            openURL(nativeUrl)
        } else if let webUrlString = link.webUrl,
                  let webUrl = URL(string: webUrlString) {
            openURL(webUrl)
        }
    }
    
    func calculateVisibility(geometry: GeometryProxy) -> Double {
        let frame = geometry.frame(in: .global)
        let intersection = frame.intersection(listFrame)
        
        if intersection.isNull { return 0 }
        
        let visibleArea = intersection.width * intersection.height
        let totalArea = frame.width * frame.height
        
        let percentage = totalArea > 0 ? Double(visibleArea / totalArea) : 0
        return (percentage * 100).rounded() / 100
    }
}
