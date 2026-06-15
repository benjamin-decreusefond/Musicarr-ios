import SwiftUI

/// Album / artist / playlist artwork with a graceful placeholder, mirroring the
/// web app's `<Cover>`.
struct Cover: View {
    let url: String?
    var size: CGFloat = 56
    var rounded: CGFloat = 6
    var circle: Bool = false

    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .background(Theme.bgElev2.clipShape(shape))
    }

    private var placeholder: some View {
        ZStack {
            Theme.bgElev2
            Image(systemName: "music.note")
                .font(.system(size: size * 0.32))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private var shape: AnyShape {
        circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: rounded, style: .continuous))
    }
}

/// A horizontal-scroll section of artwork tiles, like the web home/explore rows.
struct CardRow<Item: Identifiable, Destination: View>: View {
    let title: String
    let items: [Item]
    let tile: (Item) -> Destination

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(Theme.display(21, weight: .semibold)).foregroundStyle(Theme.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { tile($0) }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

/// Square artwork tile with a title and subtitle (albums, artists, playlists).
struct ArtTile: View {
    let cover: String?
    let title: String
    var subtitle: String?
    var circle: Bool = false
    var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Cover(url: cover, size: width, rounded: 8, circle: circle)
            Text(title)
                .font(Theme.body(14.5, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// Section title used on detail pages.
struct RowTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.display(21, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PageTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.display(30, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Centered status text (loading / empty / error).
struct StateText: View {
    let text: String
    var error: Bool = false
    var body: some View {
        Text(text)
            .font(Theme.body(14.5))
            .foregroundStyle(error ? Theme.danger : Theme.textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
            .multilineTextAlignment(.center)
    }
}

/// Pill button matching the web `.btn-primary`.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(Theme.body(14.5, weight: .bold))
            }
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(Theme.accent)
            .foregroundStyle(Theme.accentInk)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(Theme.body(14, weight: .semibold))
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
    }
}
