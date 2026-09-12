import Foundation
import Combine

/// Editable rules owned by the creation form. Preset changes are synchronous.
@MainActor
final class CustomRule: ObservableObject {
    enum PlayMode: Identifiable, CaseIterable {
        var id: Self { self }
        case single, double
        var title: String { self == .single ? "1x1" : "2x2" }
    }

    @Published var duration: Int32 { didSet { if duration != oldValue { markCustom() } } }
    @Published var goldenRule: Bool { didSet { if goldenRule != oldValue { markCustom() } } }
    @Published var playMode: PlayMode { didSet { if playMode != oldValue { markCustom() } } }
    @Published var tieBreak: Bool { didSet { if tieBreak != oldValue { markCustom() } } }
    @Published var matchType: MatchType { didSet { applyPreset() } }
    private var applyingPreset = false

    init(duration: Int32 = 1, goldenRule: Bool = false, playMode: PlayMode = .single,
         tieBreak: Bool = true, matchType: MatchType = .tennis) {
        self.duration = duration
        self.goldenRule = goldenRule
        self.playMode = playMode
        self.tieBreak = tieBreak
        self.matchType = matchType
        applyPreset()
    }

    private func markCustom() {
        if !applyingPreset && matchType != .custom { matchType = .custom }
    }

    private func applyPreset() {
        guard matchType != .custom else { return }
        applyingPreset = true
        defer { applyingPreset = false }
        duration = 1
        goldenRule = matchType == .padel
        playMode = matchType == .tennis ? .single : .double
        tieBreak = true
    }
}
