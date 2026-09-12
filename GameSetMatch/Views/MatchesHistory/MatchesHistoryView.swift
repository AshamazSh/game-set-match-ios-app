//
//  MatchesHistoryView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 11/3/24.
//

import SwiftUI

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

    @State private var showResetContentConfirmation = false
    @State private var editMode = EditMode.inactive
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.0) { pair in
                    Section(pair.0) {
                        ForEach(pair.1, id: \.objectID) { match in
                            if match.teams.allObjectsOfType(Team.self).count > 1 {
                                Button(action: {
                                    if !editMode.isEditing {
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
                                .foregroundStyle(.primary)
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
            .navigationTitle("History")
        }
    }
    
}
