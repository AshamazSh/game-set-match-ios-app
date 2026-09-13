import SwiftUI

/// Shared phone/Watch choice, occupying the same area as a team's score.
struct FirstServeTeamButton: View {
    let team: MatchState.TeamInfo
    let number: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("Team \(number) serves first")
                    #if os(watchOS)
                    .font(.headline)
                    #else
                    .font(.title2.weight(.semibold))
                    #endif
                    .multilineTextAlignment(.center)
                Text(team.players.map(\.name).joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .foregroundStyle(Color(uiColor: .systemBlue))
        #endif
        .accessibilityIdentifier("firstServeTeam\(number)")
    }
}
