import SwiftUI

struct MatchStatisticsView: View {
    let pages: [MatchStatisticsPage]
    @Binding var selectedPage: Int
    @State private var showPlayers = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if pages.first?.isDoubles == true {
                Picker("Statistics participants", selection: $showPlayers) {
                    Text("Teams").tag(false)
                    Text("Players").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .accessibilityIdentifier("statisticsParticipants")
            }
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(pages) { page in
                        statisticsPage(page)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .allowsHitTesting(page.id == selectedPage)
                            .accessibilityHidden(page.id != selectedPage)
                    }
                }
                .offset(x: -CGFloat(selectedPage) * geometry.size.width)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: selectedPage)
            }
            .clipped()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .accessibilityIdentifier("statsContent")
    }

    private func statisticsPage(_ page: MatchStatisticsPage) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text(page.title)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("statisticsPeriod")
                let participants = showPlayers ? page.players : page.teams
                ForEach(participants) { participant in
                    StatisticsTable(participant: participant,
                        opponent: showPlayers ? nil : page.teams.first { $0.team != participant.team },
                        metrics: showPlayers && page.isDoubles ? MatchStatistic.personal : MatchStatistic.allCases)
                }
                Text("Star and Golden deciding points count towards own serve, but not towards right or left serve.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if showPlayers && page.isDoubles {
                    Text("Break points, mini-breaks and games from 40:40 are team statistics in doubles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }
}

private struct StatisticsTable: View {
    let participant: ParticipantStatistics
    let opponent: ParticipantStatistics?
    let metrics: [MatchStatistic]
    @ScaledMetric(relativeTo: .subheadline) private var numberWidth: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(participant.name)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 14) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Text("Won").frame(minWidth: numberWidth)
                    Text("Total").frame(minWidth: numberWidth)
                    Text("%").frame(minWidth: numberWidth)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(metrics) { metric in
                    let count = participant[metric]
                    let comparison = opponent?[metric]
                    GridRow(alignment: .center) {
                        Text(metric.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Text(String(count.won))
                            .foregroundStyle(metric == .breakPoints && count.won > (comparison?.won ?? Int.max) ? Color.green : Color.primary)
                        Text(String(count.total))
                            .foregroundStyle(metric == .breakPoints && count.total > (comparison?.total ?? Int.max) ? Color.green : Color.primary)
                        Text(count.percentage)
                            .foregroundStyle(metric != .breakPoints && comparison.map { count.hasBetterPercentage(than: $0) } == true ? Color.green : Color.primary)
                    }
                }
            }
            .font(.subheadline)
            .monospacedDigit()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
