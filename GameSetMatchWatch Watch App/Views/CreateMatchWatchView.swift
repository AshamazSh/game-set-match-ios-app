import SwiftUI

struct CreateMatchWatchView: View {
    @State private var configuration = MatchConfiguration()
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        Form {
            Picker("Format", selection: $configuration.format) {
                ForEach(MatchFormat.allCases) { format in Text(format.title).tag(format) }
            }
            Picker("Number of sets", selection: $configuration.sets) {
                ForEach(MatchConfiguration.allowedSets, id: \.self) { sets in Text(String(sets)).tag(sets) }
            }
            Section {
                Toggle("Super tiebreak", isOn: $configuration.superTieBreak)
                    .disabled(configuration.sets == 1)
                Text(configuration.sets == 1
                     ? String(localized: "With one set, play a normal set with a tiebreak to 7 at 6:6.")
                     : configuration.decidingSetExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("At 40:40", selection: $configuration.deuceRule) {
                    ForEach(DeuceRule.allCases) { rule in Text(rule.title).tag(rule) }
                }
                Text(configuration.deuceRule.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Create") {
                connectivityManager.sendRequest(.createMatch, configuration: configuration)
            }
        }
        .onChange(of: configuration.sets) { sets in
            if sets == 1 { configuration.superTieBreak = false }
        }
    }
}
