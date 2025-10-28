import SwiftUI
import UIKit

struct SearchResultRow: View {
    @Environment(\.openURL) private var openURL

    let result: SearchResult
    @Environment(\.colorScheme) private var colorScheme
    let iconSpotifyBlack: String
    let iconSpotifyWhite: String
    let iconTidalBlack: String
    let iconTidalWhite: String
    let iconYTWhite: String
    let iconYTBlack: String

    private func open(link: PlatformLink?) {
        guard let link else { return }

        if let nativeUrlString = link.nativeUrl, let nativeUrl = URL(string: nativeUrlString), UIApplication.shared.canOpenURL(nativeUrl) {
            openURL(nativeUrl)
        } else if let webUrlString = link.webUrl, let webUrl = URL(string: webUrlString) {
            openURL(webUrl)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ArtworkCard {
                // front
                if let url = result.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure(_):
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
                // back
                VStack(alignment: .leading, spacing: 6) {
                    Text("Release Date: \(result.releaseDate)")
                    Divider()
                    Text("Songwriter: \(result.songwriter)")
                    Divider()
                    Text("Producer: \(result.producer)")
                    Divider()
                    Text("Album: \(result.album)")
                    Divider()
                    Text("Genre: \(result.genre)")
                    Divider()
                    Text("Duration: \(result.duration)")
                    Divider()
                    Text("Label: \(result.recordLabel)")
                    Divider()
                    Text("© \(result.copyright)")
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemGray6))
            }
            .frame(width: 280, height: 280)

            VStack(spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result.artist)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            HStack(spacing: 18) {
                PlatformButton(icon: .system("applelogo"), size: 44) {
                    open(link: result.links.apple) }
                PlatformButton(icon: .asset(colorScheme == .dark ? iconSpotifyWhite : iconSpotifyBlack), size: 44) { open(link: result.links.spotify) }
                PlatformButton(icon: .asset(colorScheme == .dark ? iconTidalWhite : iconTidalBlack), size: 44) { open(link: result.links.tidal) }
                PlatformButton(icon: .asset(colorScheme == .dark ? iconYTWhite : iconYTBlack ), size: 44) { open(link: result.links.youtube) }
            }
            .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
