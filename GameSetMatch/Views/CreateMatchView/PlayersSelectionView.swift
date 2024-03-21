//
//  PlayersSelectionView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 20/3/24.
//

import SwiftUI
import CoreData

struct PlayersSelectionView: View {
    @Binding var selectedPlayer: MatchPlayer
    @Binding var showCreateNewPlayer: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\.name)])
    private var players: FetchedResults<Player>
    private var filteredPlayers: [Player] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = [Player]()
        var addedNames = Set<String>()
        for player in players {
            let nameAndShortName = player.name.lowercased() + "_" + player.shortName.lowercased()
            if (search.isEmpty || player.name.lowercased().contains(search)) && !addedNames.contains(nameAndShortName) {
                result.append(player)
                addedNames.insert(nameAndShortName)
            }
        }
        
        return result
    }
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        Button {
                            dismiss()
                            showCreateNewPlayer.toggle()
                        } label: {
                            Text("Add new...")
                        }
                    }
                }
                
                Section {
                    ForEach(filteredPlayers) { player in
                        Button {
                            selectedPlayer = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName)
                            dismiss()
                        } label: {
                            PlayerNameView(viewModel: PlayerNameViewModel(player: player))
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select player")
            .interactiveDismissDisabled(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
