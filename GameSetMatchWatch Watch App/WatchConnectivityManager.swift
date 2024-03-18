//
//  WatchConnectivityManager.swift
//  GameSetMatchWatch Watch App
//
//  Created by Ashamaz on 8/3/24.
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isConnected: Bool = false
    @Published var didRecieveMatchState = false
    @Published var matchState: MatchState? = nil
    @Published var isSendingRequest = false
    private let currentTimePublisher = Timer.TimerPublisher(interval: 3.0, runLoop: .main, mode: .default)
    private var cancellable: AnyCancellable?

    private let session: WCSession
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isConnected = activationState == .activated
            self.cancellable = self.currentTimePublisher
                .autoconnect()
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] _ in
                    self?.silentRequest(.currentStatus)
                })
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.isSendingRequest = false
            self?.processMessage(message)
        }
    }

    private func silentRequest(_ request: AppRequest) {
        guard isConnected,
              !isSendingRequest,
              session.isCompanionAppInstalled,
              session.isReachable,
              session.activationState == .activated else { return }
        session.sendMessage(["request": request.rawValue]) { [weak self] message in
            DispatchQueue.main.async { [weak self] in
                self?.processMessage(message)
            }
        }
    }
    
    func sendRequest(_ request: AppRequest) {
        guard isConnected,
              !isSendingRequest,
              session.isCompanionAppInstalled,
              session.isReachable,
              session.activationState == .activated else { return }
        if matchState?.isCompleted == true,
           request != .endMatch {
            return
        }
        isSendingRequest = true
        session.sendMessage(["request": request.rawValue]) { [weak self] message in
            DispatchQueue.main.async { [weak self] in
                self?.isSendingRequest = false
                self?.processMessage(message)
            }
        } errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSendingRequest = false
            }
        }
    }
    
    private func processMessage(_ message: [String: Any]) {
        if !didRecieveMatchState {
            didRecieveMatchState = true
        }
        guard let request = message["request"] as? String,
              let action = AppRequest(rawValue: request),
              !action.isWatchRequest else { return }
        switch action {
        case .newState:
            guard let object = message["object"] as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: object),
                  let decodedMatchState = try? JSONDecoder().decode(MatchState.self, from: jsonData) else {
                matchState = nil
                return
            }
            matchState = decodedMatchState
        case .resetMatch:
            matchState = nil
        default:
            break
        }
    }
}
