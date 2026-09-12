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
    
    static func groupedMatches(_ matches: [Match]) -> [(String, [Match])] {
        let groups = Dictionary(grouping: matches, by: { $0.rule.playMode })
        return groups.keys.sorted().compactMap { key in
            guard let type = MatchType(rawValue: key), let matches = groups[key] else { return nil }
            return (type.name, matches)
        }
    }

    private var sections: [(String, [Match])] { Self.groupedMatches(Array(matches)) }

    @EnvironmentObject private var subscriptions: SubscriptionsService
    private var isSubscribed: Bool { subscriptions.hasSubscription }
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
                        ForEach(Array(pair.1.enumerated()), id: \.element.objectID) { index, match in
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
                            matchService.deleteMatches(indexSet.map { pair.1[$0] })
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
                        matchService.deleteMatches(Array(matches))
                    }),
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showSubscriptionView, content: {
                SubscriptionView()
            })
            .navigationTitle("History")
        }
    }
    
}
