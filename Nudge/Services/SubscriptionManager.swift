import SwiftUI
import Combine
import RevenueCat

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published State

    @Published var isProUser: Bool = false
    @Published var customerInfo: CustomerInfo? = nil
    @Published private(set) var offerings: Offerings? = nil
    @Published private(set) var isLoading: Bool = true

    // MARK: - Constants

    static let apiKey = "test_oJIBiCUYTNVdzkTLVXvgUMMRUVR"
    static let entitlementID = "Nudge Pro"
    static let monthlyProductID = "monthly"
    static let yearlyProductID = "yearly"

    // Free tier limit
    static let freeNudgesPerWeek = 2

    // MARK: - Init

    private init() {}

    // MARK: - Configure

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = RevenueCatDelegate.shared

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
            isLoading = false
        }
    }

    // MARK: - Refresh

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            self.isProUser = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            // Fail silently — keep current state
        }
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async {
        do {
            self.offerings = try await Purchases.shared.offerings()
        } catch {
            // Fail silently
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        self.customerInfo = result.customerInfo
        self.isProUser = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        return !result.userCancelled
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        self.isProUser = info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - Gating Logic

    func nudgesThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return PersistenceManager.shared.entries.filter { $0.createdAt >= weekStart }.count
    }

    func canCreateNudge() -> Bool {
        if isProUser { return true }
        return nudgesThisWeek() < Self.freeNudgesPerWeek
    }

    var remainingFreeNudges: Int {
        max(0, Self.freeNudgesPerWeek - nudgesThisWeek())
    }
}

// MARK: - RevenueCat Delegate

final class RevenueCatDelegate: NSObject, PurchasesDelegate, Sendable {
    static let shared = RevenueCatDelegate()

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionManager.shared.customerInfo = customerInfo
            SubscriptionManager.shared.isProUser = customerInfo.entitlements[SubscriptionManager.entitlementID]?.isActive == true
        }
    }
}
