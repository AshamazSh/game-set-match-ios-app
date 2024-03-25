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
    case goldenPoint
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
        case tiebreak
    }
    let id: Int
    let scores: [ScoreRow]
    let title: Title
    let finalScore: (TeamScore, TeamScore)?
}

class ScoreHistoryViewModel: ObservableObject {
    private var matchService: MatchService
    @Published var dismiss = false
    @Published var sections: [SetScore] = []
    @Published var team1Name = ""
    @Published var team2Name = ""
    private var cancellables = Set<AnyCancellable>()
    init(matchService: MatchService) {
        self.matchService = matchService
        if let match = matchService.match {
            calculateSections(match)
        }
    }
    
    private func subscribeToActiveMatch() {
        matchService
            .objectWillChange
            .receive(on: DispatchQueue.main)
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
    
    private func pointsString(for points: Int) -> String {
        switch points {
        case 0:
            return "0"
        case 1:
            return "15"
        case 2:
            return "30"
        default:
            return "40"
        }
    }
    
    private func calculateSections(_ match: Match) {
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
            var servedByIndex = (setIndex % ServingPlayer.allCases.count) - 1
            let games = aSet.games.allObjectsOfType(Game.self)
            var team1GamesWon = 0
            var team2GamesWon = 0
            var gameSections = [GameScoreSection]()
            for (gameIndex, game) in games.enumerated() {
                let points = game.points.allObjectsOfType(GamePoint.self)
                if !game.isTieBreak {
                    servedByIndex += 1
                }
                let servingPlayer = ServingPlayer(rawValue: servedByIndex % ServingPlayer.allCases.count) ?? .t1p1
                var servingPlayerName: String? = nil
                if let player = servingPlayer.team1ServingPlayer(players: teams[0].players.allObjectsOfType(Player.self)) {
                    servingPlayerName = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased()).name.uppercased()
                }
                if let player = servingPlayer.team2ServingPlayer(players: teams[1].players.allObjectsOfType(Player.self)) {
                    servingPlayerName = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased()).name.uppercased()
                }
                var scoreServingPlayer: ScoreServingPlayer?
                if let servingPlayerName {
                    scoreServingPlayer = ScoreServingPlayer(alignment: ScoreAlignment(servingPlayer: servingPlayer), playerName: servingPlayerName)
                } else {
                    scoreServingPlayer = nil
                }
                
                var scores = [ScoreRow]()
                var team1Points = 0
                var team2Points = 0
                if game.isTieBreak {
                    // reset order
                    servedByIndex = (setIndex % ServingPlayer.allCases.count)
                }
                for (pointIndex, point) in points.enumerated() {
                    if game.isTieBreak {
                        if pointIndex == 1 {
                            servedByIndex += 1
                        } else if pointIndex%2 == 1 {
                            servedByIndex += 1
                        }
                        var servingPlayerName: String? = nil
                        let servingPlayer = ServingPlayer(rawValue: servedByIndex % ServingPlayer.allCases.count) ?? .t1p1
                        if let player = servingPlayer.team1ServingPlayer(players: teams[0].players.allObjectsOfType(Player.self)) {
                            servingPlayerName = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased()).shortName.uppercased()
                        }
                        if let player = servingPlayer.team2ServingPlayer(players: teams[1].players.allObjectsOfType(Player.self)) {
                            servingPlayerName = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased()).shortName.uppercased()
                        }
                        if let servingPlayerName {
                            scoreServingPlayer = ScoreServingPlayer(alignment: ScoreAlignment(servingPlayer: servingPlayer), playerName: servingPlayerName)
                        } else {
                            scoreServingPlayer = nil
                        }
                    }
                    if point.winner == teams[0] {
                        team1Points += 1
                    } else {
                        team2Points += 1
                    }
                    
                    if game.isTieBreak {
                        scores.append(.regular(left: "\(team1Points)", right: "\(team2Points)", servingPlayer: scoreServingPlayer))
                    } else {
                        let isGoldenPoint = match.rule.gameTieBreak == GameTieBreak.goldenRule.rawValue
                        if max(team1Points, team2Points) > 3 {
                            if team1Points == team2Points {
                                if isGoldenPoint {
                                    scores.append(.goldenPoint)
                                } else {
                                    scores.append(.regular(left: "40", right: "40", servingPlayer: nil))
                                }
                            } else if team1Points > team2Points {
                                scores.append(.regular(left: "AD", right: "-", servingPlayer: nil))
                            } else {
                                scores.append(.regular(left: "-", right: "AD", servingPlayer: nil))
                            }
                        } else {
                            scores.append(.regular(left: "\(self.pointsString(for: team1Points))", right: "\(self.pointsString(for: team2Points))", servingPlayer: nil))
                        }
                    }
                }
                if let winner = game.winner {
                    if winner == teams[0] {
                        team1GamesWon += 1
                    } else {
                        team2GamesWon += 1
                    }
                    let team1TeamScore = TeamScore(value: "\(team1GamesWon)", hasWon: winner == teams[0])
                    let team2TeamScore = TeamScore(value: "\(team2GamesWon)", hasWon: winner != teams[0])
                    scores.removeLast()
                    
                    gameSections.append(GameScoreSection(id: gameIndex,
                                                         scores: scores,
                                                         title: game.isTieBreak
                                                         ? .tiebreak
                                                         : .servingPlayer(scoreServingPlayer),
                                                         finalScore: (team1TeamScore, team2TeamScore)))
                } else {
                    gameSections.append(GameScoreSection(id: gameIndex,
                                                         scores: scores,
                                                         title: game.isTieBreak
                                                         ? .tiebreak
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
    private let scoreHeaderWidth: CGFloat = 20
    private let separatorWidth: CGFloat = 20
    @ObservedObject var viewModel: ScoreHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTabIndex: Int = 0
    
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
            VStack(spacing: 0) {
                ZStack {
                    HStack(alignment: .center) {
                        Text(viewModel.team1Name)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                        Spacer()
                        Text(viewModel.team2Name)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    if let (left, right) = setScore(forIndex: selectedTabIndex) {
                        HStack {
                            Text(left.value)
                                .frame(width: scoreHeaderWidth)
                                .multilineTextAlignment(.center)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .foregroundStyle(left.hasWon ? .green : .primary)
                            Text(right.value)
                                .frame(width: scoreHeaderWidth)
                                .multilineTextAlignment(.center)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .foregroundStyle(right.hasWon ? .green : .primary)
                        }
                    }
                }
                .padding(.horizontal)
                Divider()
                    .padding(.top)
                TabView(selection: $selectedTabIndex) {
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
                                        case .goldenPoint:
                                            HStack {
                                                Spacer()
                                                Text("40")
                                                    .frame(width: scoreWidth)
                                                    .multilineTextAlignment(.center)
                                                Text(":")
                                                    .frame(width: separatorWidth)
                                                    .multilineTextAlignment(.center)
                                                Text("40")
                                                    .frame(width: scoreWidth)
                                                    .multilineTextAlignment(.center)
                                                Spacer()
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
                                                Text(":")
                                                    .font(.title)
                                                    .frame(width: separatorWidth)
                                                    .multilineTextAlignment(.center)
                                                Text(right.value)
                                                    .font(.title)
                                                    .frame(width: scoreWidth)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(right.hasWon ? .green : .primary)
                                                Spacer()
                                            }
                                        }
                                    }
                                } header: {
                                    switch game.title {
                                    case .tiebreak:
                                        HStack {
                                            Spacer()
                                            Text("TIEBREAK")
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
                        .tag(section.id)
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .background(Color(UIColor.systemGroupedBackground))
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.dismiss) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
            .navigationTitle("Game log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
