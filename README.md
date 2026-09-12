# Game, Set, Match

SwiftUI scorekeeper for tennis and padel, with an Apple Watch remote.
Open `GameSetMatch.xcworkspace` in Xcode. The project currently retains its CocoaPods integration (no third-party pods).

## Architecture

- `MatchEngine` and `MatchRules`: pure Swift decisions for scoring, service rotation and best-of-N completion.
- `CoreDataManager`: main-actor repository. Creating, scoring, undoing and deleting are each a single transaction. A failed save rolls back the whole command.
- `MatchService`: active match session. Restores the selected match, routes commands, publishes committed snapshots and reports errors.
- `ConnectivityManager` / `WatchConnectivityManager`: request/reply transport and latest-state synchronization. Each modern command includes a request ID, match ID and expected persisted revision. Duplicate requests are ignored; stale commands return the current snapshot and an error. Background synchronization carries snapshots, never scoring commands.
- `SubscriptionsService`: shared entitlement state, verified StoreKit transactions and subscription status. Only subscribed/grace-period states grant access.
- `AppDependencies`: one retained instance of each service. View-owned form and history models use `StateObject`.

## Persistence and compatibility

`GameSetMatchV2` is the current model. The shipped `GameSetMatch` model is retained for automatic lightweight migration. V2 adds a persisted match revision and changes `Match.rule` deletion from Cascade to Nullify. Existing shared rules survive deletion of another match. New matches own independent rule snapshots; the repository removes rules only when no remaining match references them.

New custom matches use best-of-1/3/5/7/9. Existing matches with even durations remain readable and require a majority of sets. Closing a match clears the active selection without deleting its history. Undo is available even after the winning point.

Historical service labels use the recorded `GamePoint.servedBy`. Old records are not rewritten to guess which person actually served. New points use the corrected continuous service rotation, including tiebreak boundaries.

Modern snapshots have an increasing transport version, so delayed messages cannot replace a newer score or reopen a closed match. Legacy request dictionaries remain accepted for compatibility; they lack the revision and duplicate protections of the updated Watch app. After a communication failure, the Watch app asks the user to check the score before retrying.

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

Choose simulator names installed on your machine. Tests use isolated stores and defaults. Coverage includes deuce/advantage, golden point, tiebreak service, best-of-five, undo, injected save failures, old-store migration, shared-rule deletion, command ordering/deduplication, history updates and stale Watch snapshots. Real-device connectivity and App Store billing flows still need device/sandbox testing before release.
