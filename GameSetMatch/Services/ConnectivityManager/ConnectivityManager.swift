//
//  ConnectivityManager.swift
//  GameSetMatch
//
//  Created by Ashamaz on 8/3/24.
//

import Foundation
import WatchConnectivity

class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    private var isConnected: Bool = false
    private var matchState: MatchState? = nil
    @Published var requestedAction: AppRequest?
    private var replyHandler: (([String : Any]) -> Void)?
    private let session: WCSession
    init(session: WCSession = .default) {
        self.session = session
        self.isConnected = session.activationState == .activated
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    private func sendMessage(_ message: [String: Any]) {
        if let replyHandler {
            replyHandler(message)
            self.replyHandler = nil
        } else {
            session.sendMessage(message,
                                replyHandler: nil)
        }
    }
    
    func sendState(_ state: MatchState?) {
        guard isConnected,
              session.isWatchAppInstalled,
              session.isReachable,
              session.activationState == .activated else {
            return
        }
        if let state = state {
            if let data = try? JSONEncoder().encode(state),
               let jsonMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                sendMessage(["request": AppRequest.newState.rawValue,
                             "object": jsonMessage])
            }
        } else {
            sendMessage(["request": AppRequest.resetMatch.rawValue])
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        isConnected = false
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        isConnected = false
        session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        switch activationState {
        case .activated:
            if !self.isConnected {
                self.isConnected = true
                self.sendState(matchState)
            }
        default:
            self.isConnected = false
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let request = message["request"] as? String,
              let action = AppRequest(rawValue: request),
              action.isWatchRequest else { return }
        DispatchQueue.main.async { [weak self] in
            self?.requestedAction = action
            self?.replyHandler?(["request": AppRequest.ignored.rawValue])
            self?.replyHandler = replyHandler
        }
    }
}
