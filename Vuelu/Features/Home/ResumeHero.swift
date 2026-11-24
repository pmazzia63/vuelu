import SwiftUI

/// The big "Reprendre" card for the most recently followed work.
struct ResumeHero: View {
    let work: Work
    let namespace: Namespace.ID
    var onAdvance: ((Work) -> Void)?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink(value: work) {
                content
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: work.id, in: namespace)

            Button {
                withAnimation(.snappy) { work.advance() }
                onAdvance?(work)
            } label: {
                Label(work.nextActionLabel, systemImage: "plus")
                    .font(.rounded(.subheadline))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.brandFill)
            .controlSize(.large)
            .sensoryFeedback(.increase, trigger: work.lastProgressAt)
            .padding(18)
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("REPRENDRE")
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.brandDeep)
                Text(work.title)
                    .font(.rounded(.title2))
                    .lineLimit(2)
                Text(work.positionText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let hint = work.totalHint {
                    HStack(spacing: 6) {
                        BookmarkGauge(fraction: work.progressFraction, tint: work.kind.tint)
                            .frame(width: 12, height: 15)
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                ProgressStamp(work: work)
                Spacer(minLength: 52)
            }
            Spacer(minLength: 0)
            CoverView(work: work, cornerRadius: 14, showsTitle: true)
                .frame(width: 92, height: 132)
                .shadow(color: work.kind.tint.opacity(0.5), radius: 16, y: 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color.surface
                LinearGradient(
                    colors: [work.kind.tint.opacity(0.45), work.kind.tint.opacity(0.05)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
            .clipShape(.rect(cornerRadius: 30, style: .continuous))
        }
        .shadow(color: Color.brandDeep.opacity(0.12), radius: 20, y: 10)
        .contentShape(.rect(cornerRadius: 30))
    }
}
