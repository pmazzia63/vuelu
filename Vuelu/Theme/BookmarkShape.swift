import SwiftUI

/// The logo's silhouette: a rounded ribbon bookmark with a soft notch at the bottom.
/// Used as the app's recurring "you stopped here" motif.
nonisolated struct BookmarkShape: Shape {
    /// Depth of the bottom notch, as a fraction of the height (the logo uses ~0.19).
    var notchDepth: CGFloat = 0.19

    func path(in rect: CGRect) -> Path {
        let corner = min(rect.width, rect.height) * 0.15
        let tip = corner * 0.55
        let notch = CGPoint(x: rect.midX, y: rect.maxY - rect.height * notchDepth)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: corner
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: corner
        )
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: notch, radius: tip)
        path.addArc(tangent1End: notch, tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: tip * 0.6)
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY),
            radius: tip
        )
        path.closeSubpath()
        return path
    }
}

/// A bookmark that fills from the top as the current saison / tome progresses.
struct BookmarkGauge: View {
    let fraction: Double?
    var tint: Color = .brand

    var body: some View {
        BookmarkShape()
            .fill(tint.opacity(0.22))
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(tint.gradient)
                        .frame(height: proxy.size.height * (fraction ?? 0))
                }
            }
            .clipShape(BookmarkShape())
            .animation(.smooth, value: fraction)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        BookmarkShape().fill(Color.brand).frame(width: 80, height: 92)
        BookmarkGauge(fraction: 0.6).frame(width: 60, height: 72)
        BookmarkGauge(fraction: nil, tint: WorkKind.manga.tint).frame(width: 60, height: 72)
    }
    .padding()
    .background(Color.canvas)
}
