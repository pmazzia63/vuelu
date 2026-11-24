import SwiftUI
import UIKit

extension Font {
    /// SF Pro Rounded, the app's display face.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

// MARK: - Surfaces

private struct SurfaceCard: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: .rect(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.brandDeep.opacity(0.07), radius: 14, y: 6)
    }
}

extension View {
    func surfaceCard(padding: CGFloat = 18) -> some View {
        modifier(SurfaceCard(padding: padding))
    }

    /// The app's soft lavender backdrop.
    func canvasBackground() -> some View {
        background {
            LinearGradient(
                colors: [Color.brand.opacity(0.18), Color.canvas, Color.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Cover

/// The work's cover, or a tinted placeholder carrying the bookmark motif.
struct CoverView: View {
    let kind: WorkKind
    let title: String
    let imageData: Data?
    var cornerRadius: CGFloat = 16
    var showsTitle = false

    init(work: Work, cornerRadius: CGFloat = 16, showsTitle: Bool = false) {
        self.init(kind: work.kind, title: work.title, imageData: work.coverImage, cornerRadius: cornerRadius, showsTitle: showsTitle)
    }

    init(kind: WorkKind, title: String, imageData: Data?, cornerRadius: CGFloat = 16, showsTitle: Bool = false) {
        self.kind = kind
        self.title = title
        self.imageData = imageData
        self.cornerRadius = cornerRadius
        self.showsTitle = showsTitle
    }

    var body: some View {
        Color.clear
            .overlay {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [kind.tint, kind.tint.mix(with: .brand, by: 0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: kind.symbol)
                    .font(.system(size: side * 0.3, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                if showsTitle {
                    Text(title)
                        .font(.system(size: max(side * 0.11, 9), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .padding(side * 0.08)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .overlay(alignment: .topTrailing) {
                BookmarkShape()
                    .fill(.white.opacity(0.85))
                    .frame(width: side * 0.14, height: side * 0.2)
                    .padding(.trailing, side * 0.1)
            }
        }
    }
}

// MARK: - Badges

struct KindBadge: View {
    let kind: WorkKind

    var body: some View {
        Label(kind.label, systemImage: kind.symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(kind.tint.opacity(0.25), in: .capsule)
            .foregroundStyle(Color.primary.opacity(0.8))
    }
}

struct NewReleaseBadge: View {
    let work: Work

    var body: some View {
        Label(work.kind.newReleaseShort(mode: work.mode), systemImage: "sparkle")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandDeep.gradient, in: .capsule)
            .foregroundStyle(.white)
    }
}

/// Bottom-of-screen line under a card: either a new-release badge or "il y a 3 jours".
struct ProgressStamp: View {
    let work: Work

    var body: some View {
        if work.hasNewRelease() {
            NewReleaseBadge(work: work)
        } else {
            Label {
                Text(work.lastProgressAt, format: .relative(presentation: .named, unitsStyle: .wide))
            } icon: {
                Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundStyle(Color.inkSecondary)
        }
    }
}

// MARK: - Advance

/// The "+1" button: a glass circle tinted with the work's colour.
struct AdvanceButton: View {
    let work: Work
    var onAdvance: ((Work) -> Void)?

    var body: some View {
        Button {
            withAnimation(.snappy) { work.advance() }
            onAdvance?(work)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .frame(width: 48, height: 48)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(work.kind.tint.opacity(0.5)).interactive(), in: .circle)
        .sensoryFeedback(.increase, trigger: work.lastProgressAt)
        .accessibilityLabel(work.nextActionLabel)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            BookmarkShape()
                .fill(Color.brand.gradient)
                .frame(width: 64, height: 76)
                .shadow(color: Color.brand.opacity(0.35), radius: 18, y: 10)
            VStack(spacing: 6) {
                Text(title).font(.rounded(.title2))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, systemImage: "plus", action: action)
                    .buttonStyle(.glassProminent)
                    .tint(Color.brandFill)
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Navigation

extension View {
    /// Pushes `WorkDetailView` with a zoom transition from the tapped card.
    func workDestination(in namespace: Namespace.ID) -> some View {
        navigationDestination(for: Work.self) { work in
            WorkDetailView(work: work)
                .navigationTransition(.zoom(sourceID: work.id, in: namespace))
        }
    }
}
