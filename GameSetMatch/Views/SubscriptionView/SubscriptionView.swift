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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SubscriptionStoreView(groupID: SubscriptionsService.passGroupId) {
            VStack {
                Image("logo")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                Text("Ace Access")
                    .font(.largeTitle).fontWeight(.bold)
                    .padding(.bottom)
                Text("Unlock advanced match customization and all matches history")
                    .fontWeight(.medium)
                    .padding(.horizontal, 32)
            }
            .padding()
            .containerBackground(for: .subscriptionStoreFullHeight) {
                ZStack {
                    Image("subscription_background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    (colorScheme == .light
                     ? Color.white.opacity(0.65)
                     : Color.black.opacity(0.6))
                }
            }
        }
        .backgroundStyle(.clear)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .redeemCode)
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyForegroundStyle(colorScheme == .light ? Color.black : Color.white)
        .subscriptionStorePolicyDestination(url: URL(string: "https://sites.google.com/view/ashamazsh-gamesetmatch")!, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!, for: .termsOfService)
        .subscriptionStorePickerItemBackground(.thinMaterial)
        .productDescription(.hidden)
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
