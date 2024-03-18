//
//  SubscriptionsService.swift
//  GameSetMatch
//
//  Created by Ashamaz on 16/3/24.
//

import StoreKit
import Combine

class SubscriptionsService: ObservableObject {
    static let passGroupId = "21465250"
    
    private enum SubscriptionTypes: String, CaseIterable {
        case annual = "gsm_aa_999_1y_1w0"
        case monthly = "gsm_aa_099_1y_1w0"
    }

    static func hasSubscription(in statuses: [Product.SubscriptionInfo.Status]) -> Bool {
        for status in statuses {
            switch status.state {
            case .expired, .revoked:
                continue
            default:
                return true
            }
        }
        
        return false
    }
    
    @Published var hasSubscription = false
    
    init(hasSubscription: Bool = false) {
        self.hasSubscription = hasSubscription
    }
}
