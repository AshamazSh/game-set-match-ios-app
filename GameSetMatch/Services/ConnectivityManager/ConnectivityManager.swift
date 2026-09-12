import Foundation
import WatchConnectivity

struct WatchCommand {
    let action: AppRequest
    let requestID: String?
    let matchID: String?
    let revision: Int64?
}

enum CommandError: LocalizedError {
    case staleState, invalidRequest
    var errorDescription: String? {
        switch self {
        case .staleState: return String(localized: "The match has changed. Check the score and try again.")
        case .invalidRequest: return String(localized: "Unable to process the watch request.")
        }
    }
}

@MainActor
protocol MatchTransport: AnyObject {
    var onCommand: ((WatchCommand) throws -> Void)? { get set }
    func sendState(_ state: MatchState?)
}

@MainActor
final class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate, MatchTransport {
    var onCommand: ((WatchCommand) throws -> Void)?
    private var matchState: MatchState?
    private let session: WCSession
    private let defaults: UserDefaults
    private var snapshotVersion: Int64
    private var handledRequests: [String] = []
    private static let versionKey = "com.gamesetmatch.snapshotVersion"

    init(session: WCSession = .default, defaults: UserDefaults = .standard, activate: Bool = true) {
        self.session = session
        self.defaults = defaults
        snapshotVersion = Int64(defaults.integer(forKey: Self.versionKey))
        super.init()
        if activate && WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    func sendState(_ state: MatchState?) {
        matchState = state // Retain the snapshot even when the watch is unreachable.
        snapshotVersion += 1
        defaults.set(snapshotVersion, forKey: Self.versionKey)
        publish()
    }

    private func snapshot() -> [String: Any] {
        var message: [String: Any] = ["request": AppRequest.resetMatch.rawValue, "snapshotVersion": snapshotVersion]
        if let state = matchState,
           let data = try? JSONEncoder().encode(state),
           let object = try? JSONSerialization.jsonObject(with: data) {
            message["request"] = AppRequest.newState.rawValue
            message["object"] = object
        }
        return message
    }

    private func publish() {
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        let message = snapshot()
        // Context delivers the latest snapshot after reconnecting; commands are never queued here.
        do { try session.updateApplicationContext(message) }
        catch { /* A reachable request will still receive the current snapshot directly. */ }
        if session.isReachable { session.sendMessage(message, replyHandler: nil, errorHandler: { _ in }) }
    }

    /// Runs synchronously on the main actor: one request, one mutation, one reply.
    func receive(_ message: [String: Any], reply: ([String: Any]) -> Void) {
        var response: [String: Any]
        let requestID = message["requestID"] as? String
        do {
            guard let raw = message["request"] as? String, let action = AppRequest(rawValue: raw), action.isWatchRequest,
                  let onCommand else { throw CommandError.invalidRequest }
            if !(requestID.map { handledRequests.contains($0) } ?? false) {
                try onCommand(WatchCommand(action: action, requestID: requestID,
                    matchID: message["matchID"] as? String, revision: (message["revision"] as? NSNumber)?.int64Value))
                if let requestID {
                    handledRequests.append(requestID)
                    if handledRequests.count > 256 { handledRequests.removeFirst() }
                }
            }
            response = snapshot()
        } catch {
            response = snapshot()
            response["error"] = error.localizedDescription
        }
        response["requestID"] = requestID
        reply(response)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.publish() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.publish() }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { replyHandler(["request": AppRequest.ignored.rawValue]); return }
            self.receive(message, reply: replyHandler)
        }
    }
}
