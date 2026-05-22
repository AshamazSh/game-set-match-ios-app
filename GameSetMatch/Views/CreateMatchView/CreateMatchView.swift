//
//  CreateMatchView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//

import SwiftUI
import CoreData
import Combine

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
    
    func isValid(for type: MatchType, customRule: CustomRule) -> Bool {
        switch type {
        case .tennis, .tennis2x2, .padel:
            return true
        case .custom:
            switch customRule.playMode {
            case .single:
                return isValid(for: .tennis, customRule: customRule)
            case .double:
                return isValid(for: .tennis2x2, customRule: customRule)
            }
        }
    }
    
    func players() -> [MatchPlayer] {
        return [firstPlayer, secondPlayer]
    }
}

class CustomRule: ObservableObject {
    enum PlayMode: Identifiable, CaseIterable {
        var id: Self { self }
        
        case single
        case double
        
        var title: String {
            switch self {
            case .single:
                "1x1"
            case .double:
                "2x2"
            }
        }
    }
    @Published var duration: Int32 = 3
    @Published var playMode = PlayMode.double
    @Published var fortyAllRule = FortyAllRule.startPoint
    @Published var deciderSetRule = DeciderSetRule.fullSet
    @Published var matchType: MatchType = MatchType.tennis
    private var cancellables = Set<AnyCancellable>()
    
    init(duration: Int32 = 3,
         playMode: PlayMode = PlayMode.double,
         fortyAllRule: FortyAllRule = .startPoint,
         deciderSetRule: DeciderSetRule = .fullSet,
         matchType: MatchType = MatchType.tennis) {
        self.duration = duration
        self.playMode = playMode
        self.fortyAllRule = fortyAllRule
        self.deciderSetRule = deciderSetRule
        self.matchType = matchType
        
        subscribeToChanges()
    }
    
    private func subscribeToChanges() {
        $duration
            .subscribe(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard let self else { return }
                if newValue == 1 {
                    self.deciderSetRule = .fullSet
                }
            }
            .store(in: &cancellables)
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
        self._team1 = ObservedObject(initialValue: TeamInfo(isFirstTeam: true, context: context))
        self._team2 = ObservedObject(initialValue: TeamInfo(isFirstTeam: false, context: context))
    }
    
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var matchService: MatchService
    @ObservedObject private var team1: TeamInfo
    @ObservedObject private var team2: TeamInfo
    @ObservedObject private var customRule: CustomRule = CustomRule()
    @State private var selectedPlayer: SelectedPlayer? = nil
    private var isValid: Bool {
        return team1.isValid(for: customRule.matchType, customRule: customRule) && team2.isValid(for: customRule.matchType, customRule: customRule)
    }
    
    private var matchTypeDescription: some View {
        VStack {
            VStack {
                LabeledContent("Sets:") {
                    Stepper(String(customRule.duration)) {
                        guard customRule.duration < 9 else { return }
                        customRule.duration += 2
                    } onDecrement: {
                        guard customRule.duration > 1 else { return }
                        customRule.duration -= 2
                    }
                }
                LabeledContent("40:40 decider") {
                    Picker(selection: $customRule.fortyAllRule, label: EmptyView()) {
                        ForEach(FortyAllRule.allCases) { rule in
                            Text(rule.title)
                        }
                    }
                    .pickerStyle(.menu)
                }
                if customRule.duration > 1 {
                    LabeledContent("Decider set") {
                        Picker(selection: $customRule.deciderSetRule, label: EmptyView()) {
                            ForEach(DeciderSetRule.allCases) { rule in
                                Text(rule.title)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                LabeledContent("Mode") {
                    Picker(selection: $customRule.playMode, label: EmptyView()) {
                        ForEach(CustomRule.PlayMode.allCases) { type in
                            Text(type.title)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    private var isSingleMatch: Bool {
        customRule.playMode == .single
    }
    
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
            if !isSingleMatch,
               selectedPlayer == .team1player1 || selectedPlayer == .team2player1 {
                Text("Serves first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    matchTypeDescription
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
                    matchService.createMatch(.custom,
                                             customRule: customRule,
                                             players1: Array(team1.players().prefix(isSingleMatch ? 1 : 2)),
                                             players2: Array(team2.players().prefix(isSingleMatch ? 1 : 2)))
                } label: {
                    Text("Create")
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Create new match")
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
