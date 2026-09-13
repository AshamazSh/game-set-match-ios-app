# Game, Set, Match

SwiftUI scorekeeper for tennis and padel, with an Apple Watch remote. All features are available without a subscription: custom rules, the complete match history and replaying finished matches.
Open `GameSetMatch.xcworkspace` in Xcode. The project currently retains its CocoaPods integration (no third-party pods).

## Architecture

- `MatchEngine` and `MatchRules`: pure Swift decisions for scoring, service rotation and best-of-N completion.
- `CoreDataManager`: main-actor repository. Creating, scoring, undoing and deleting are each a single transaction. A failed save rolls back the whole command.
- `MatchService`: active match session. Restores the selected match, routes commands, publishes committed snapshots and reports errors.
- `ConnectivityManager` / `WatchConnectivityManager`: request/reply transport and latest-state synchronization. Each modern command includes a request ID, match ID and expected persisted revision. Duplicate requests are ignored; stale commands return the current snapshot and an error. Background synchronization carries snapshots, never scoring commands.
- `AppDependencies`: one retained instance of each service. View-owned form and history models use `StateObject`.

## Persistence and compatibility

`GameSetMatchV4` is the current model. All previous models (`GameSetMatch`, `GameSetMatchV2`, and `GameSetMatchV3`) are retained unchanged, including their original version hashes. Automatic lightweight migration adds optional `Rule.formatCode` and `Rule.deuceRuleCode` strings, plus `Rule.superTieBreak`, `MatchSet.isSuperTieBreak`, and `Rule.notifySideChanges` booleans defaulting to false.

For a migrated rule with no deuce code, the repository reads the original `gameTieBreak` value: Golden point stays Golden point, everything else keeps advantage scoring. Original set counts (including 7/9 and even legacy durations), the old first-to-six option, players, point history, results and service records remain intact. Opening a finished match does not recalculate or rewrite its result. Replay copies its original scoring rules even when they are no longer offered by the new creation form.

V2's safe Nullify relationship for `Match.rule` is retained. Existing shared rules survive another match's deletion. New matches own independent rule snapshots; the repository removes rules only when no remaining match references them. Migrations do not reset or replace user stores. Migration tests create actual V1/V2/V3 SQLite stores, reopen them as V4 and verify continued scoring and replay.

## New match configuration

1. **Format:** 1×1 (default) or 2×2; each team has one or two players.
2. **Number of sets:** best-of-1/3/5, default 3. Win a majority of sets.
3. **Deciding set:** normal (default) or super tiebreak. When enabled, 1:1 in best-of-three or 2:2 in best-of-five creates a single tiebreak to 10, win by two. A one-set match always plays a normal set. Ordinary sets retain a tiebreak to 7 at 6:6, win by two.
4. **At 40:40:** Star point (default), Golden point or Adv. Star point allows advantage at the first and second deuce; the third deuce (raw point count 5:5) is a deciding point. Golden point decides immediately at 3:3. Adv has no deuce limit and requires two consecutive points from deuce.
Side-change notifications are always active, including in existing matches; there is no setting.

The iPhone and Watch forms share `MatchConfiguration`. Settings 3 and 4 show explanatory subtitles. New history entries are grouped by format; legacy entries retain their sport categories. A super tiebreak is persisted as a flagged set containing one tiebreak game; the set score displays actual points (for example 10:8), not games (1:0). Undo restores both ordinary and super-tiebreak boundaries. The fixed first server remains the first player of team one, with no order-selection UI.

Closing a match clears the active selection without deleting its history. Undo remains available after the winning point.

Historical service labels use the recorded `GamePoint.servedBy`. Old records are not rewritten to guess which person actually served. New points use the corrected continuous service rotation, including tiebreak boundaries.

Modern snapshots have an increasing transport version, so delayed messages cannot replace a newer score or reopen a closed match. New Watch creation commands carry all four configuration values. Legacy sport-specific creation commands retain their old one-set rules. Legacy request dictionaries remain accepted for compatibility; they lack the revision and duplicate protections of the updated Watch app. After a communication failure, the Watch app asks the user to check the score before retrying.

## Validation

List simulator destinations with `xcodebuild -workspace GameSetMatch.xcworkspace -scheme GameSetMatch -showdestinations`.

```sh
xcodebuild -workspace GameSetMatch.xcworkspace -scheme GameSetMatch \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

xcodebuild -workspace GameSetMatch.xcworkspace -scheme GameSetMatch \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GameSetMatchTests -parallel-testing-enabled NO test

xcodebuild -workspace GameSetMatch.xcworkspace -scheme 'GameSetMatchWatch Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:'GameSetMatchWatch Watch AppTests' -parallel-testing-enabled NO test
```

Choose simulator names installed on your machine. Tests use isolated stores and defaults. Coverage includes Star/Golden/Adv, ordinary and super tiebreaks, service, best-of-five, undo, injected save failures, V1/V2/V3 store migration, shared-rule deletion, Watch rule payloads, command ordering/deduplication, history updates and stale Watch snapshots. A UI test checks defaults, the player-count switch, subtitles, the one-set restriction and creating a configured match. It uses the debug-only `--ui-testing` launch flag for isolated storage and disabled Watch connectivity. Real-device connectivity still needs device testing before release.

Side-change notifications are unconditional. The unused V4 `Rule.notifySideChanges` attribute is retained solely for store compatibility; its value has no effect. A completed odd game in a normal set, every sixth tiebreak point, and super-tiebreak points 1, 7, 13… trigger notifications only after a successful save. A normal tiebreak ending the set completes game 13. Match completion suppresses notifications. Undo and opening history do not trigger them.

The phone and Watch share a 0.3 s fade-in, 0.5 s clockwise 180° rotation, and 0.3 s fade-out. The phone uses a light gray padded rounded square with a white icon; Watch replaces the content with a full-screen presentation. Reduce Motion disables rotation. Older OS versions use a compatible rotation symbol. Transient UUID/timestamp events travel in optional snapshot fields; Watch ignores repeated, cached, and expired events (over 3 seconds). Events are not persisted in the match database.
