import StoreKit
import Combine

@MainActor
final class SubscriptionsService: ObservableObject {
    static let passGroupId = "21465250"
    @Published private(set) var hasSubscription = false

    static func grantsAccess(_ state: Product.SubscriptionInfo.RenewalState) -> Bool {
        state == .subscribed || state == .inGracePeriod
    }

    static func hasSubscription(in statuses: [Product.SubscriptionInfo.Status]) -> Bool {
        statuses.contains { status in
            guard grantsAccess(status.state),
                  case .verified(let transaction) = status.transaction,
                  case .verified = status.renewalInfo else { return false }
            return transaction.subscriptionGroupID == passGroupId && transaction.revocationDate == nil
        }
    }

    func update(_ statuses: [Product.SubscriptionInfo.Status]) {
        hasSubscription = Self.hasSubscription(in: statuses)
    }

    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.subscriptionGroupID == Self.passGroupId,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        hasSubscription = entitled
    }

    func observeTransactions() async {
        await refresh()
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            if case .verified(let transaction) = result {
                await refresh()
                await transaction.finish()
            }
        }
    }
}
