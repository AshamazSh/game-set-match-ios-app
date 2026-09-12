//
//  CreateMatchView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class TeamInfo: ObservableObject {
    @Published var firstPlayer: MatchPlayer
    @Published var secondPlayer: MatchPlayer
    
    init(isFirstTeam: Bool, context: NSManagedObjectContext) {
        let request = Match.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Match.createdAt, ascending: false)]
        request.fetchLimit = 1
        var firstPlayer: MatchPlayer = isFirstTeam ? .playerOne : .playerTwo
        var secondPlayer: MatchPlayer = isFirstTeam ? .playerOneB : .playerTwoB
        if let lastMatch = try? context.fetch(request).first {
            if isFirstTeam {
                if let teams = lastMatch.teams.allObjectsOfType(Team.self).first {
                    let players = teams.players.allObjectsOfType(Player.self)
                    if players.count > 0 {
                        firstPlayer = players[0].matchPlayer
                    }
                    if players.count > 1 {
                        secondPlayer = players[1].matchPlayer
                    }
                }
            } else {
                if let teams = lastMatch.teams.allObjectsOfType(Team.self).last {
                    let players = teams.players.allObjectsOfType(Player.self)
                    if players.count > 0 {
                        firstPlayer = players[0].matchPlayer
                    }
                    if players.count > 1 {
                        secondPlayer = players[1].matchPlayer
                    }
                }
            }
        }
        self.firstPlayer = firstPlayer
        self.secondPlayer = secondPlayer
    }
    
    func players() -> [MatchPlayer] {
        return [firstPlayer, secondPlayer]
    }
}

struct CreateMatchView: View {
    private enum SelectedPlayer: Identifiable, Hashable {
        var id: Self { self }
        
        case team1player1
        case team1player2
        case team2player1
        case team2player2
    }
    
    init(context: NSManagedObjectContext) {
        self._team1 = StateObject(wrappedValue: TeamInfo(isFirstTeam: true, context: context))
        self._team2 = StateObject(wrappedValue: TeamInfo(isFirstTeam: false, context: context))
    }
    
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var matchService: MatchService
    @StateObject private var team1: TeamInfo
    @StateObject private var team2: TeamInfo
    @StateObject private var customRule: CustomRule = CustomRule()
    @State private var selectedPlayer: SelectedPlayer? = nil
    private var matchSettings: some View {
        Section {
            Picker("Format", selection: $customRule.configuration.format) {
                ForEach(MatchFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .accessibilityIdentifier("matchFormat")
            Picker("Number of sets", selection: $customRule.configuration.sets) {
                ForEach(MatchConfiguration.allowedSets, id: \.self) { sets in
                    Text(String(sets)).tag(sets)
                }
            }
            .accessibilityIdentifier("matchSets")
            VStack(alignment: .leading, spacing: 6) {
                Picker("Deciding set", selection: $customRule.configuration.superTieBreak) {
                    Text("Normal set").tag(false)
                    Text("Super tiebreak").tag(true)
                }
                .disabled(customRule.configuration.sets == 1)
                .accessibilityIdentifier("decidingSet")
                Text(customRule.configuration.sets == 1
                     ? String(localized: "With one set, play a normal set with a tiebreak to 7 at 6:6.")
                     : customRule.configuration.decidingSetExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Picker("At 40:40", selection: $customRule.configuration.deuceRule) {
                    ForEach(DeuceRule.allCases) { rule in Text(rule.title).tag(rule) }
                }
                .accessibilityIdentifier("deuceRule")
                Text(customRule.configuration.deuceRule.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isSingleMatch: Bool { customRule.configuration.format == .singles }

    private func playerNameViewModel(for selectedPlayer: SelectedPlayer) -> PlayerNameViewModel {
        switch selectedPlayer {
        case .team1player1:
            return PlayerNameViewModel(matchPlayer: team1.firstPlayer)
        case .team1player2:
            return PlayerNameViewModel(matchPlayer: team1.secondPlayer)
        case .team2player1:
            return PlayerNameViewModel(matchPlayer: team2.firstPlayer)
        case .team2player2:
            return PlayerNameViewModel(matchPlayer: team2.secondPlayer)
        }
    }
    private func playerButton(for selectedPlayer: SelectedPlayer) -> some View {
        HStack {
            Button {
                self.selectedPlayer = selectedPlayer
            } label: {
                PlayerNameView(viewModel: playerNameViewModel(for: selectedPlayer))
            }
            .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    matchSettings
                    if isSingleMatch {
                        Section("Player 1") {
                            playerButton(for: .team1player1)
                        }
                        Section("Player 2") {
                            playerButton(for: .team2player1)
                        }
                    } else {
                        Section("Team 1") {
                            playerButton(for: .team1player1)
                            playerButton(for: .team1player2)
                        }
                        Section("Team 2") {
                            playerButton(for: .team2player1)
                            playerButton(for: .team2player2)
                        }
                    }
                }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                Button {
                    matchService.perform {
                        matchService.match = try coreDataManager.createMatch(
                            configuration: customRule.configuration,
                            players1: Array(team1.players().prefix(isSingleMatch ? 1 : 2)),
                            players2: Array(team2.players().prefix(isSingleMatch ? 1 : 2)))
                    }
                } label: {
                    Text("Create")
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                }
                .disabled(!customRule.configuration.isValid)
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Create new match")
            .onChange(of: customRule.configuration.sets) { _, sets in
                if sets == 1 { customRule.configuration.superTieBreak = false }
            }
            .sheet(item: $selectedPlayer) { selectedPlayer in
                switch selectedPlayer {
                case .team1player2:
                    PlayersSelectionView(selectedPlayer: $team1.secondPlayer)
                case .team2player1:
                    PlayersSelectionView(selectedPlayer: $team2.firstPlayer)
                case .team2player2:
                    PlayersSelectionView(selectedPlayer: $team2.secondPlayer)
                default:
                    PlayersSelectionView(selectedPlayer: $team1.firstPlayer)
                }
            }
        }
    }
    
}
