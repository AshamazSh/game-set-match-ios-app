//
//  SubscriptionView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 16/3/24.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SubscriptionStoreView(groupID: SubscriptionsService.passGroupId) {
            Text("")
                .containerBackground(for: .subscriptionStoreFullHeight) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
        }
        .backgroundStyle(.clear)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .redeemCode)
        .subscriptionStorePickerItemBackground(.thinMaterial)
        .onInAppPurchaseCompletion { product, result in
            switch result {
            case .success(let purchaseResult):
                switch purchaseResult {
                case .success(_), .pending:
                    dismiss()
                case .userCancelled:
                    print("cancelled")
                @unknown default:
                    print("wtf")
                }
            default:
                break
            }
        }
    }
}

#Preview {
    SubscriptionView()
}
