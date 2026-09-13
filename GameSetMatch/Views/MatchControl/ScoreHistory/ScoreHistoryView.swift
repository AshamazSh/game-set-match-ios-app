//
//  ScoreHistoryView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 24/3/24.
//

import SwiftUI
import Combine

enum ScoreAlignment {
    case left
    case center
    case right
    
    init(servingPlayer: ServingPlayer) {
        switch servingPlayer {
        case .t1p1, .t1p2:
            self = .left
        case .t2p1, .t2p2:
            self = .right
        }
    }
}

struct ScoreServingPlayer {
    let alignment: ScoreAlignment
    let playerName: String
}

enum ScoreRow {
    case regular(left: String, right: String, servingPlayer: ScoreServingPlayer?)
    case decidingPoint(DeuceRule)
}

struct TeamScore {
    let value: String
    let hasWon: Bool
}

struct SetScore: Identifiable {
    let id: Int
    let games: [GameScoreSection]
    let finalScore: (TeamScore, TeamScore)?
}

struct GameScoreSection: Identifiable {
    enum Title {
        case servingPlayer(ScoreServingPlayer?)
        case tiebreak(isSuper: Bool)
    }
    let id: Int
    let scores: [ScoreRow]
    let title: Title
    let finalScore: (TeamScore, TeamScore)?
    var isBreak = false
}

@MainActor
class ScoreHistoryViewModel: ObservableObject {
    private var matchService: MatchService
    @Published var dismiss = false
    @Published var sections: [SetScore] = []
    @Published var statistics: [MatchStatisticsPage] = []
    @Published var isMatchCompleted = false
    @Published var team1Name = ""
    @Published var team2Name = ""
    private var cancellables = Set<AnyCancellable>()
    init(matchService: MatchService) {
        self.matchService = matchService
        subscribeToActiveMatch()
    }
    
    private func subscribeToActiveMatch() {
        matchService
            .$matchState
            .sink(receiveValue: { [weak self] _ in
                guard let self else { return }
                if let match = self.matchService.match {
                    self.calculateSections(match)
                } else {
                    self.dismiss = true
                }
            })
            .store(in: &cancellables)
    }
    
    private func calculateSections(_ match: Match) {
        isMatchCompleted = match.winner != nil
        statistics = MatchStatisticsCalculator.pages(for: match, rules: matchService.coreDataManager.rules(for: match))
        let teams = match.teams.allObjectsOfType(Team.self)
        guard teams.count > 1 else { return }
        var team1Name = ""
        for player in teams[0].players.allObjectsOfType(Player.self) {
            if !team1Name.isEmpty {
                team1Name += "\n"
            }
            team1Name += player.name
        }
        self.team1Name = team1Name
        var team2Name = ""
        for player in teams[1].players.allObjectsOfType(Player.self) {
            if !team2Name.isEmpty {
                team2Name += "\n"
            }
            team2Name += player.name
        }
        self.team2Name = team2Name
        
        var sections = [SetScore]()
        let sets = match.sets.allObjectsOfType(MatchSet.self)
        var team1WonSets = 0
        var team2WonSets = 0
        for (setIndex, aSet) in sets.enumerated() {
            let games = aSet.games.allObjectsOfType(Game.self)
            var team1GamesWon = 0
            var team2GamesWon = 0
            var gameSections = [GameScoreSection]()
            for (gameIndex, game) in games.enumerated() {
                let points = game.points.allObjectsOfType(GamePoint.self)
                let servingTeam = points.first.flatMap { point in
                    teams.first { $0.players.contains(point.servedBy) }
                }
                let scoreServingPlayer = points.first.map { point in
                    ScoreServingPlayer(alignment: teams[0].players.contains(point.servedBy) ? .left : .right,
                                       playerName: point.servedBy.name.uppercased())
                }

                var scores = [ScoreRow]()
                var team1Points = 0
                var team2Points = 0
                for point in points {
                    let pointServer = ScoreServingPlayer(
                        alignment: teams[0].players.contains(point.servedBy) ? .left : .right,
                        playerName: point.servedBy.shortName.uppercased())
                    if point.winner == teams[0] {
                        team1Points += 1
                    } else {
                        team2Points += 1
                    }
                    
                    let score = MatchEngine.Score(first: Int32(team1Points), second: Int32(team2Points))
                    let (left, right) = MatchEngine.displayPoints(score, isTieBreak: game.isTieBreak)
                    let deuceRule = matchService.coreDataManager.rules(for: match).deuceRule
                    if !game.isTieBreak && MatchEngine.isDecidingPoint(score, rule: deuceRule) {
                        scores.append(.decidingPoint(deuceRule))
                    } else {
                        scores.append(.regular(left: left, right: right, servingPlayer: game.isTieBreak ? pointServer : nil))
                    }
                }
                if let winner = game.winner {
                    if winner == teams[0] {
                        team1GamesWon += 1
                    } else {
                        team2GamesWon += 1
                    }
                    let team1TeamScore = TeamScore(value: String(aSet.isSuperTieBreak ? team1Points : team1GamesWon), hasWon: winner == teams[0])
                    let team2TeamScore = TeamScore(value: String(aSet.isSuperTieBreak ? team2Points : team2GamesWon), hasWon: winner != teams[0])
                    if !scores.isEmpty { scores.removeLast() }
                    
                    gameSections.append(GameScoreSection(id: gameIndex,
                                                         scores: scores,
                                                         title: game.isTieBreak
                                                         ? .tiebreak(isSuper: aSet.isSuperTieBreak)
                                                         : .servingPlayer(scoreServingPlayer),
                                                         finalScore: (team1TeamScore, team2TeamScore),
                                                         isBreak: !game.isTieBreak && servingTeam.map { $0 != winner } == true))
                } else {
                    gameSections.append(GameScoreSection(id: gameIndex,
                                                         scores: scores,
                                                         title: game.isTieBreak
                                                         ? .tiebreak(isSuper: aSet.isSuperTieBreak)
                                                         : .servingPlayer(scoreServingPlayer),
                                                         finalScore: nil))
                }
            }
            if let winner = aSet.winner {
                if winner == teams[0] {
                    team1WonSets += 1
                } else {
                    team2WonSets += 1
                }
                let team1TeamScore = TeamScore(value: "\(team1WonSets)", hasWon: winner == teams[0])
                let team2TeamScore = TeamScore(value: "\(team2WonSets)", hasWon: winner != teams[0])
                
                sections.append(SetScore(id: setIndex,
                                         games: gameSections,
                                         finalScore: (team1TeamScore, team2TeamScore)))
            } else {
                sections.append(SetScore(id: setIndex,
                                         games: gameSections,
                                         finalScore: nil))
            }
        }
        
        self.sections = sections
    }
}

struct ScoreHistoryView: View {
    private let scoreWidth: CGFloat = 50
    private let separatorWidth: CGFloat = 20
    @StateObject private var viewModel: ScoreHistoryViewModel
    init(matchService: MatchService) {
        _viewModel = StateObject(wrappedValue: ScoreHistoryViewModel(matchService: matchService))
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTabIndex: Int = 0
    @State private var showStats = false
    @State private var selectedStatsIndex = 0
    private var hasPreviousSet: Bool { showStats ? selectedStatsIndex > 0 : selectedTabIndex > 0 }
    private var hasNextSet: Bool {
        showStats ? selectedStatsIndex + 1 < viewModel.statistics.count : selectedTabIndex + 1 < viewModel.sections.count
    }

    private func openStatistics() {
        selectedStatsIndex = viewModel.isMatchCompleted ? 0 : min(selectedTabIndex + 1, max(0, viewModel.statistics.count - 1))
        showStats = true
    }

    private func setScore(forIndex index: Int) -> (TeamScore, TeamScore)? {
        guard index < viewModel.sections.count else { return (TeamScore(value: "0", hasWon: false), TeamScore(value: "0", hasWon: false)) }
        if let (left, right) = viewModel.sections[index].finalScore {
            return (left, right)
        }
        var currentIndex = index - 1
        while currentIndex >= 0 {
            if let (left, right) = viewModel.sections[currentIndex].finalScore {
                return (TeamScore(value: left.value, hasWon: false), TeamScore(value: right.value, hasWon: false))
            }
            currentIndex -= 1
        }
        
        return (TeamScore(value: "0", hasWon: false), TeamScore(value: "0", hasWon: false))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                scoreContent
                    .opacity(showStats ? 0 : 1)
                    .allowsHitTesting(!showStats)
                    .accessibilityHidden(showStats)
                if showStats {
                    MatchStatisticsView(pages: viewModel.statistics, selectedPage: $selectedStatsIndex)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onChange(of: viewModel.sections.count) { _, count in
                selectedTabIndex = min(selectedTabIndex, max(0, count - 1))
                selectedStatsIndex = min(selectedStatsIndex, count)
            }
            .onChange(of: viewModel.dismiss) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
            .navigationTitle(showStats ? "Stats" : "Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        Button { showStats = false } label: { Text(verbatim: "Score") }
                        Button { openStatistics() } label: { Text(verbatim: "Stats") }
                    } label: {
                        HStack(spacing: 6) {
                            Text(verbatim: showStats ? "Stats" : "Score")
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("matchDetailsMenu")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        guard hasPreviousSet else { return }
                        if showStats { selectedStatsIndex -= 1 } else { selectedTabIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(hasPreviousSet ? Color.accentColor : Color.gray)
                    }
                    .disabled(!hasPreviousSet)
                    .accessibilityLabel("Previous set")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard hasNextSet else { return }
                        if showStats { selectedStatsIndex += 1 } else { selectedTabIndex += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(hasNextSet ? Color.accentColor : Color.gray)
                    }
                    .disabled(!hasNextSet)
                    .accessibilityLabel("Next set")
                }
            }
            .toolbarBackground(Color(UIColor.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var scoreContent: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(viewModel.sections) { section in
                        List {
                            ForEach(section.games) { game in
                                Section {
                                    ForEach(Array(game.scores.enumerated()), id: \.offset) { index, score in
                                        switch score {
                                        case .regular(let left, let right, let servingPlayer):
                                            ZStack {
                                                HStack {
                                                    Spacer()
                                                    Text(left)
                                                        .frame(width: scoreWidth)
                                                        .multilineTextAlignment(.center)
                                                    Text(":")
                                                        .frame(width: separatorWidth)
                                                        .multilineTextAlignment(.center)
                                                    Text(right)
                                                        .frame(width: scoreWidth)
                                                        .multilineTextAlignment(.center)
                                                    Spacer()
                                                }
                                                if let servingPlayer {
                                                    HStack {
                                                        if servingPlayer.alignment == .right {
                                                            Spacer()
                                                        }
                                                        Text(servingPlayer.playerName)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                        if servingPlayer.alignment == .left {
                                                            Spacer()
                                                        }
                                                    }
                                                }
                                            }
                                        case .decidingPoint(let rule):
                                            VStack {
                                                if rule != .star {
                                                    Text(rule.title).font(.caption).foregroundStyle(.secondary)
                                                }
                                                HStack {
                                                    Spacer()
                                                    Text(rule.decidingPointScore)
                                                        .frame(width: scoreWidth)
                                                        .multilineTextAlignment(.center)
                                                    Text(":")
                                                        .frame(width: separatorWidth)
                                                        .multilineTextAlignment(.center)
                                                    Text(rule.decidingPointScore)
                                                        .frame(width: scoreWidth)
                                                        .multilineTextAlignment(.center)
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                    if let (left, right) = game.finalScore {
                                        VStack {
                                            Divider()
                                            HStack {
                                                Spacer()
                                                Text(left.value)
                                                    .font(.title)
                                                    .frame(width: scoreWidth)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(left.hasWon ? .green : .primary)
                                                    .overlay(alignment: .trailing) {
                                                        if game.isBreak && left.hasWon {
                                                            Text(verbatim: "Breakpoint!")
                                                                .font(.caption.weight(.semibold))
                                                                .foregroundStyle(.green)
                                                                .fixedSize()
                                                                .offset(x: -(scoreWidth + 8))
                                                        }
                                                    }
                                                Text(":")
                                                    .font(.title)
                                                    .frame(width: separatorWidth)
                                                    .multilineTextAlignment(.center)
                                                Text(right.value)
                                                    .font(.title)
                                                    .frame(width: scoreWidth)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(right.hasWon ? .green : .primary)
                                                    .overlay(alignment: .leading) {
                                                        if game.isBreak && right.hasWon {
                                                            Text(verbatim: "Breakpoint!")
                                                                .font(.caption.weight(.semibold))
                                                                .foregroundStyle(.green)
                                                                .fixedSize()
                                                                .offset(x: scoreWidth + 8)
                                                        }
                                                    }
                                                Spacer()
                                            }
                                        }
                                    }
                                } header: {
                                    switch game.title {
                                    case .tiebreak(let isSuper):
                                        HStack {
                                            Spacer()
                                            Text(isSuper ? String(localized: "Super tiebreak") : String(localized: "TIEBREAK"))
                                            Spacer()
                                        }
                                    case .servingPlayer(let servedPlayer):
                                        if let servedPlayer {
                                            HStack {
                                                if servedPlayer.alignment == .right {
                                                    Spacer()
                                                }
                                                Label(servedPlayer.playerName, systemImage: "tennisball.fill")
                                                    .environment(\.layoutDirection, servedPlayer.alignment == .right ? .rightToLeft : .leftToRight)
                                                if servedPlayer.alignment == .left {
                                                    Spacer()
                                                }
                                            }
                                        } else {
                                            Text("")
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                        .scrollIndicators(.hidden)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(section.id == selectedTabIndex)
                        .accessibilityHidden(section.id != selectedTabIndex)
                    }
                }
                // Move the whole strip so outgoing and incoming pages travel together.
                .offset(x: -CGFloat(selectedTabIndex) * geometry.size.width)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: selectedTabIndex)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Keep scrolling rows above the fixed team and score footer.
            .clipped()
            if let (left, right) = setScore(forIndex: selectedTabIndex) {
                Divider()
                HStack(spacing: 12) {
                    Text(viewModel.team1Name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 0) {
                        Text(left.value)
                            .frame(minWidth: scoreWidth)
                            .foregroundStyle(left.hasWon ? .green : .primary)
                        Text(":")
                            .frame(width: separatorWidth)
                            .foregroundStyle(.secondary)
                        Text(right.value)
                            .frame(minWidth: scoreWidth)
                            .foregroundStyle(right.hasWon ? .green : .primary)
                    }
                    .font(.title2.bold())
                    .monospacedDigit()
                    Text(viewModel.team2Name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
