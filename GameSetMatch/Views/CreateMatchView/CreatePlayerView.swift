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
    
    @State private var errorMessage: String?
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
                        let player = MatchPlayer(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 shortName: shortName.trimmingCharacters(in: .whitespacesAndNewlines))
                        newPlayer = try coreDataManager.createPlayer(player).matchPlayer
                    } catch { errorMessage = error.localizedDescription }
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
            .alert("Unable to complete action", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

#Preview {
    CreatePlayerView(newPlayer: .constant(MatchPlayer(name: "", shortName: "")))
}
