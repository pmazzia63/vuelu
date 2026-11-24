import Charts
import SwiftData
import SwiftUI

/// Time watched, pages read and units consumed, from the progress history.
struct StatsView: View {
    @Query(sort: \Work.lastProgressAt, order: .reverse) private var works: [Work]
    @Namespace private var namespace
    @AppStorage("statsPeriod") private var period: StatsPeriod = .month
    @State private var metric: Metric = .time

    enum Metric: String, CaseIterable, Identifiable {
        case time, pages, units
        var id: String { rawValue }
        var label: String {
            switch self {
            case .time: "Temps"
            case .pages: "Pages"
            case .units: "Avancées"
            }
        }
    }

    var body: some View {
        NavigationStack {
            let stats = ReadingStats(works: works, period: period)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Période", selection: $period.animation(.snappy)) {
                        ForEach(StatsPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if stats.isEmpty {
                        EmptyStateView(
                            title: "Pas encore de stats",
                            message: "Chaque « +1 » compte ici.\nAjoute la durée d'un épisode ou le nombre de pages\ndans une œuvre pour suivre ton temps et tes pages."
                        )
                        .padding(.top, 40)
                    } else {
                        summary(stats)
                        chartCard(stats)
                        topWorksCard(stats)
                        if !stats.worksMissingLength.isEmpty {
                            missingLengthCard(stats.worksMissingLength)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .canvasBackground()
            .navigationTitle("Statistiques")
            .workDestination(in: namespace)
        }
    }

    // MARK: Summary

    private func summary(_ stats: ReadingStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(value: Self.duration(stats.minutes), caption: "regardées", symbol: "play.tv.fill", tint: WorkKind.series.tint)
            StatTile(value: stats.pages.formatted(), caption: stats.pages > 1 ? "pages lues" : "page lue", symbol: "book.pages.fill", tint: WorkKind.book.tint)
            ForEach(StatUnit.allCases) { unit in
                if let count = stats.units[unit] {
                    StatTile(value: count.formatted(), caption: unit.label(count), symbol: unit.symbol, tint: .brand)
                }
            }
            StatTile(
                value: stats.activeDays.formatted(),
                caption: stats.activeDays > 1 ? "jours actifs" : "jour actif",
                symbol: "flame.fill",
                tint: WorkKind.bd.tint
            )
        }
    }

    // MARK: Chart

    private func chartCard(_ stats: ReadingStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Mesure", selection: $metric.animation(.snappy)) {
                ForEach(Metric.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            let values = stats.buckets.filter { value(of: $0) > 0 }
            if values.isEmpty {
                Text(metric == .time
                     ? "Renseigne la durée d'un épisode pour voir ton temps de visionnage."
                     : "Renseigne le nombre de pages pour voir tes pages lues.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .multilineTextAlignment(.center)
            } else {
                Chart(values) { bucket in
                    BarMark(
                        x: .value("Date", bucket.start, unit: period.bucket),
                        y: .value(metric.label, chartValue(of: bucket))
                    )
                    .foregroundStyle(by: .value("Type", bucket.kind.label))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale(
                    domain: WorkKind.allCases.map(\.label),
                    range: WorkKind.allCases.map(\.tint)
                )
                .chartYAxisLabel(metric == .time ? "heures" : "")
                .frame(height: 200)
            }
        }
        .surfaceCard()
    }

    private func value(of bucket: ReadingStats.Bucket) -> Int {
        switch metric {
        case .time: bucket.minutes
        case .pages: bucket.pages
        case .units: bucket.units
        }
    }

    private func chartValue(of bucket: ReadingStats.Bucket) -> Double {
        metric == .time ? Double(bucket.minutes) / 60 : Double(value(of: bucket))
    }

    // MARK: Top works

    private func topWorksCard(_ stats: ReadingStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Les plus suivies", systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            ForEach(stats.topWorks.prefix(5)) { total in
                NavigationLink(value: total.work) {
                    HStack(spacing: 12) {
                        CoverView(work: total.work, cornerRadius: 8)
                            .frame(width: 34, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(total.work.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("\(total.units) \(total.work.statUnit.label(total.units))")
                                .font(.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Spacer()
                        if let amount = amountText(total) {
                            Text(amount)
                                .font(.rounded(.subheadline))
                                .monospacedDigit()
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: total.work.id, in: namespace)
            }
        }
        .surfaceCard()
    }

    private func amountText(_ total: ReadingStats.WorkTotal) -> String? {
        if total.minutes > 0 { return Self.duration(total.minutes) }
        if total.pages > 0 { return "\(total.pages.formatted()) p." }
        return nil
    }

    private func missingLengthCard(_ works: [Work]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Durée ou pages manquantes", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            Text("Pas comptées en temps ou en pages : \(works.prefix(4).map(\.title).formatted(.list(type: .and)))\(works.count > 4 ? "…" : ""). Ajoute-les depuis « Modifier ».")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .surfaceCard(padding: 14)
    }

    /// "12 h 30", "45 min".
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours.formatted()) h" : "\(hours.formatted()) h \(String(format: "%02d", rest))"
    }
}

private struct StatTile: View {
    let value: String
    let caption: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.rounded(.title2))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .surfaceCard(padding: 14)
    }
}

#Preview {
    StatsView().modelContainer(.preview)
}
