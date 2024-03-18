//
//  CreateMatchView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//

import SwiftUI
import CoreData
import StoreKit
import Combine

class TeamInfo: ObservableObject {
    @Published var firstPlayerName: String = "Player A"
    @Published var firstPlayerShortName: String = "PLA"
    @Published var secondPlayerName: String = "Player B"
    @Published var secondPlayerShortName: String = "PLB"
    
    func isValid(for type: MatchType, customRule: CustomRule) -> Bool {
        switch type {
        case .tennis:
            return !firstPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !firstPlayerShortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tennis2x2, .padel:
            return !firstPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !firstPlayerShortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !secondPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !secondPlayerShortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        return [MatchPlayer(name: firstPlayerName.trimmingCharacters(in: .whitespacesAndNewlines), shortName: firstPlayerShortName.trimmingCharacters(in: .whitespacesAndNewlines)),
                MatchPlayer(name: secondPlayerName.trimmingCharacters(in: .whitespacesAndNewlines), shortName: secondPlayerShortName.trimmingCharacters(in: .whitespacesAndNewlines))]
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
    @Published var duration: Int32 = 1
    @Published var goldenRule = false
    @Published var playMode = PlayMode.single
    @Published var tieBreak = true
    @Published var matchType: MatchType = MatchType.tennis
    private var cancellables = Set<AnyCancellable>()

    init(duration: Int32 = 1, goldenRule: Bool = false, playMode: PlayMode = PlayMode.single, tieBreak: Bool = true, matchType: MatchType = MatchType.tennis) {
        self.duration = duration
        self.goldenRule = goldenRule
        self.playMode = playMode
        self.tieBreak = tieBreak
        self.matchType = matchType
        
        subscribeToChanges()
    }
    
    private func subscribeToChanges() {
        $duration
            .subscribe(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard let self,
                self.matchType != .custom else { return }
                if newValue > 1 {
                    self.matchType = .custom
                }
            }
            .store(in: &cancellables)

        $goldenRule
            .subscribe(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard let self else { return }
                switch self.matchType {
                case .tennis, .tennis2x2:
                    if newValue == true {
                        self.matchType = .custom
                    }
                case .padel:
                    if newValue == false {
                        self.matchType = .custom
                    }
                case .custom:
                    break
                }
            }
            .store(in: &cancellables)

        $tieBreak
            .subscribe(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard let self else { return }
                switch self.matchType {
                case .tennis, .tennis2x2, .padel:
                    if newValue == false {
                        self.matchType = .custom
                    }
                case .custom:
                    break
                }
            }
            .store(in: &cancellables)

        $matchType
            .subscribe(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                guard let self else { return }
                switch newValue {
                case .tennis:
                    self.duration = 1
                    self.goldenRule = false
                    self.tieBreak = true
                    self.playMode = .single
                    
                case .tennis2x2:
                    self.duration = 1
                    self.goldenRule = false
                    self.tieBreak = true
                    self.playMode = .double

                case .padel:
                    self.duration = 1
                    self.goldenRule = true
                    self.tieBreak = true
                    self.playMode = .double

                case .custom:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

struct CreateMatchView: View {
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @ObservedObject private var team1: TeamInfo = TeamInfo()
    @ObservedObject private var team2: TeamInfo = TeamInfo()
    @ObservedObject private var customRule: CustomRule = CustomRule()
    @State private var isSubscribed: Bool = false
    @State private var showSubscriptionView = false
    private var isValid: Bool {
        if !isSubscribed && customRule.matchType == .custom {
            return false
        }
        return team1.isValid(for: customRule.matchType, customRule: customRule) && team2.isValid(for: customRule.matchType, customRule: customRule)
    }
    
    private var matchTypeDescription: some View {
        VStack {
            VStack {
                LabeledContent("Sets:") {
                    Stepper(String(customRule.duration)) {
                        guard customRule.duration < 9 else { return }
                        customRule.duration += 1
                    } onDecrement: {
                        guard customRule.duration > 1 else { return }
                        customRule.duration -= 1
                    }
                }
                LabeledContent {
                    Toggle(isOn: $customRule.tieBreak) {
                        EmptyView()
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Tiebreak")
                        Text("Played on 6:6")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent {
                    Toggle(isOn: $customRule.goldenRule) {
                        EmptyView()
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Golden point")
                        Text("Played on 40:40")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if customRule.matchType == .custom {
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
            .disabled(customRule.matchType == .custom && !isSubscribed)
            .blur(radius: customRule.matchType == .custom && !isSubscribed ? 4 : 0)

            if customRule.matchType == .custom && !isSubscribed {
                Button("Subscribe to Ace Access to set your own rules") {
                    showSubscriptionView.toggle()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .padding(.bottom)
            }
        }
    }
    
    private var isSingleMatch: Bool {
        customRule.matchType == .tennis || customRule.matchType == .custom && customRule.playMode == .single
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    LabeledContent("Rules") {
                        Picker(selection: $customRule.matchType, label: EmptyView()) {
                            ForEach(MatchType.allCases) { type in
                                Text(type.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    matchTypeDescription
                    if isSingleMatch {
                        Section("Player 1") {
                            TextField("Player name", text: $team1.firstPlayerName)
                            TextField("Short name", text: $team1.firstPlayerShortName)
                                .textInputAutocapitalization(.characters)
                        }
                        Section("Player 2") {
                            TextField("Player name", text: $team2.secondPlayerName)
                            TextField("Short name", text: $team2.secondPlayerShortName)
                                .textInputAutocapitalization(.characters)
                        }
                    } else {
                        Section("Team 1") {
                            TextField("Player 1", text: $team1.firstPlayerName)
                            TextField("Short name", text: $team1.firstPlayerShortName)
                                .textInputAutocapitalization(.characters)
                            TextField("Player 2", text: $team1.secondPlayerName)
                            TextField("Short name", text: $team1.secondPlayerShortName)
                                .textInputAutocapitalization(.characters)
                        }
                        Section("Team 2") {
                            TextField("Player 1", text: $team2.firstPlayerName)
                            TextField("Short name", text: $team2.firstPlayerShortName)
                                .textInputAutocapitalization(.characters)
                            TextField("Player 2", text: $team2.secondPlayerName)
                            TextField("Short name", text: $team2.secondPlayerShortName)
                                .textInputAutocapitalization(.characters)
                        }
                    }
                }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                Button {
                    try? coreDataManager.createMatch(customRule.matchType,
                                                     customRule: customRule.matchType == .custom ? customRule : nil,
                                                     players1: Array(team1.players().prefix(isSingleMatch ? 1 : 2)),
                                                     players2: Array(team2.players().suffix(isSingleMatch ? 1 : 2)))
                } label: {
                    Text("Create")
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Create new match")
            .sheet(isPresented: $showSubscriptionView) {
                SubscriptionView()
            }
            .subscriptionStatusTask(for: SubscriptionsService.passGroupId) { taskState in
                if let statuses = taskState.value {
                    isSubscribed = SubscriptionsService.hasSubscription(in: statuses)
                }
            }
            .task {
                for await result in Transaction.updates {
                    let transaction = checkVerified(result)

                    await self.updateCustomerProductStatus()

                    await transaction?.finish()
                }
            }
        }
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = checkVerified(result) {
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) -> T? {
        ///Check whether the JWS passes StoreKit verification.
        switch result {
        case .verified(let safe):
            return safe
        default:
            return nil
        }
    }
}

#Preview {
    CreateMatchView()
}
