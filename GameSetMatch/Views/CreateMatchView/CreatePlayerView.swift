//
//  CreatePlayerView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 20/3/24.
//

import SwiftUI

struct CreatePlayerView: View {
    @State private var name: String = ""
    @State private var shortName: String = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager
    
    @Binding var newPlayer: MatchPlayer
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    TextField("Full name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Short name", text: $shortName)
                        .textInputAutocapitalization(.characters)
                }
                Spacer()
                
                Button {
                    do {
                        _ = try coreDataManager.createPlayer(MatchPlayer(name: name, shortName: shortName))
                        newPlayer = MatchPlayer(name: name, shortName: shortName)
                    } catch {
                        coreDataManager.rollback()
                    }
                } label: {
                    Text("Create")
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("New player")
            .interactiveDismissDisabled(true)
        }
    }
}

#Preview {
    CreatePlayerView(newPlayer: .constant(MatchPlayer(name: "", shortName: "")))
}
