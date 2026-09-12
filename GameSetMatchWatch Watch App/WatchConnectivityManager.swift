import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var isConnected = false
    @Published private(set) var didRecieveMatchState = false
    @Published private(set) var matchState: MatchState?
    @Published private(set) var isSendingRequest = false
    @Published var errorMessage: String?
    private var snapshotVersion: Int64 = -1
    private let session: WCSession

    init(session: WCSession = .default, activate: Bool = true) {
        self.session = session
        super.init()
        if activate && WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isConnected = activationState == .activated && session.isReachable
            self.processMessage(session.receivedApplicationContext)
            if self.isConnected { self.sendRequest(.currentStatus) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isConnected = session.activationState == .activated && session.isReachable
            if self.isConnected { self.sendRequest(.currentStatus) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in self?.processMessage(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in self?.processMessage(applicationContext) }
    }

    func sendRequest(_ request: AppRequest) {
        guard !isSendingRequest else { return }
        guard session.isCompanionAppInstalled, session.isReachable, session.activationState == .activated else {
            isConnected = false
            if request != .currentStatus { errorMessage = String(localized: "Connect to your iPhone and try again.") }
            return
        }
        var message: [String: Any] = ["request": request.rawValue, "requestID": UUID().uuidString]
        message["matchID"] = matchState?.matchID
        message["revision"] = matchState?.revision
        isSendingRequest = true
        session.sendMessage(message, replyHandler: { [weak self] response in
            Task { @MainActor [weak self] in
                self?.isSendingRequest = false
                self?.processMessage(response)
                self?.errorMessage = response["error"] as? String
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSendingRequest = false
                self?.errorMessage = String(localized: "Could not confirm the action. Check the score on your iPhone before trying again.")
            }
        })
    }

    func processMessage(_ message: [String: Any]) {
        guard let raw = message["request"] as? String, let action = AppRequest(rawValue: raw),
              action == .newState || action == .resetMatch else { return }
        let version = (message["snapshotVersion"] as? NSNumber)?.int64Value
        if let version, version < snapshotVersion { return }
        // Once a modern snapshot arrived, a delayed legacy packet must not overwrite it.
        if version == nil && snapshotVersion >= 0 { return }
        if action == .newState {
            guard let object = message["object"] as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: object),
                  let state = try? JSONDecoder().decode(MatchState.self, from: data) else { return }
            matchState = state
        } else { matchState = nil }
        if let version { snapshotVersion = version }
        didRecieveMatchState = true
    }
}
