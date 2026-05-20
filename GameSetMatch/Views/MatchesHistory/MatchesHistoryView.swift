//
//  MatchesHistoryView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 11/3/24.
//

import SwiftUI
import StoreKit

struct MatchesHistoryView: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var matchService: MatchService
    @FetchRequest(sortDescriptors: [
        SortDescriptor(\.createdAt, order: .reverse)
    ])
    var matches: FetchedResults<Match>

    private func teamName(_ team: Team) -> String {
        var name = ""
        for player in team.players.allObjectsOfType(Player.self) {
            if !name.isEmpty {
                name += " / "
            }
            name += player.shortName
        }
        
        return name
    }
    
    private func dateToString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yy"
        
        return dateFormatter.string(from: date)
    }
    
    private var sections: [(String, [Match])] {
        var allMatches = [String: [Match]]()
        for match in matches {
            if let playMode = MatchType(rawValue: match.rule.playMode) {
                var current = allMatches[playMode.name] ?? [Match]()
                current.append(match)
                allMatches[match.rule.name] = current
            }
        }
        var result = [(String, [Match])]()
        for key in allMatches.keys.sorted() {
            if let current = allMatches[key] {
                result.append((key, current))
            }
        }
        
        return result
    }
    
    @State private var isSubscribed: Bool = false
    @State private var showSubscriptionView = false
    @State private var showResetContentConfirmation = false
    @State private var editMode = EditMode.inactive
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        NavigationStack {
            List {
                if !isSubscribed,
                   !matches.isEmpty {
                    Button(action: {
                        showSubscriptionView.toggle()
                    }, label: {
                        Text("Subscribe to Pro Features to see all matches history")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    })
                    .listRowInsets(EdgeInsets())
                    .padding(.top)
                    .buttonStyle(.bordered)
                    .listRowBackground(Color.clear)
                    .deleteDisabled(true)
                }
                ForEach(sections, id: \.0) { pair in
                    Section(pair.0) {
                        ForEach(Array(pair.1.enumerated()), id: \.offset) { index, match in
                            if match.teams.allObjectsOfType(Team.self).count > 1 {
                                Button(action: {
                                    if !editMode.isEditing && (isSubscribed || index == 0) {
                                        matchService.match = match
                                    }
                                }, label: {
                                    NavigationLink {
                                        EmptyView()
                                    } label: {
                                        HStack(spacing: 8) {
                                            VStack(spacing: 8) {
                                                Text(teamName(match.teams.allObjectsOfType(Team.self)[0]))
                                                Text(teamName(match.teams.allObjectsOfType(Team.self)[1]))
                                            }
                                            VStack(spacing: 8) {
                                                Text(String(match.teams.allObjectsOfType(Team.self)[0].finalScore))
                                                Text(String(match.teams.allObjectsOfType(Team.self)[1].finalScore))
                                            }
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal)
                                            Spacer()
                                            Text(dateToString(match.createdAt))
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                })
                                .opacity(isSubscribed || index == 0 ? 1 : 0.6)
                                .blur(radius: isSubscribed || index == 0 ? 0 : 4)
                                .disabled(!isSubscribed && index != 0)
                                .foregroundStyle(.primary)
                                .if(!isSubscribed && index == 0) { view in
                                    view.deleteDisabled(true)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                context.delete(pair.1[index])
                            }
                            do {
                                try context.save()
                            } catch {
                                context.rollback()
                            }
                        }
                    }
                }
            }
            .overlay(content: {
                if matches.isEmpty {
                    Text("No matches played")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            })
            .toolbar {
                if !matches.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showResetContentConfirmation.toggle()
                        } label: {
                            Text("Clear")
                        }
                        .foregroundStyle(.red)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .alert(isPresented: $showResetContentConfirmation) {
                Alert(
                    title: Text("Delete all matches?"),
                    message: Text("This action can't be reverted"),
                        primaryButton: .destructive(Text("Yes"), action: {
                            for match in matches {
                                context.delete(match)
                            }
                            do {
                                try context.save()
                            } catch {
                                context.rollback()
                            }
                        }),
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showSubscriptionView, content: {
                SubscriptionView()
            })
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
            .navigationTitle("History")
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
