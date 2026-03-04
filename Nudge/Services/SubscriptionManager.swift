import SwiftUI
import Combine
import RevenueCat

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published State

    @Published fileprivate(set) var isProUser: Bool = false
    @Published fileprivate(set) var customerInfo: CustomerInfo? = nil
    @Published private(set) var offerings: Offerings? = nil
    @Published private(set) var isLoading: Bool = true

    // MARK: - Constants

    static var apiKey: String {
        return (Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String) ?? ""
    }

    static let entitlementID = "Nudge Pro"
    static let monthlyProductID = "monthly"
    static let yearlyProductID = "yearly"

    // Free tier limit
    static let freeNudgesPerWeek = 2

    // MARK: - Init

    private(set) var isConfigured = false

    private init() {}

    // MARK: - Configure

    func configure() {
        let key = Self.apiKey
        #if !DEBUG
        // RevenueCat hard-crashes Release builds if a test_ key is used — skip gracefully
        guard !key.isEmpty && !key.hasPrefix("test_") else {
            isLoading = false
            return
        }
        #else
        guard !key.isEmpty else {
            isLoading = false
            return
        }
        #endif
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: key)
        Purchases.shared.delegate = RevenueCatDelegate.shared
        isConfigured = true

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
            isLoading = false
        }
    }

    // MARK: - Refresh

    func refreshCustomerInfo() async {
        guard isConfigured else { return }
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
        guard isConfigured else { return }
        do {
            self.offerings = try await Purchases.shared.offerings()
        } catch {
            // Fail silently
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> Bool {
        guard isConfigured else { throw NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subscriptions unavailable"]) }
        let result = try await Purchases.shared.purchase(package: package)
        self.customerInfo = result.customerInfo
        self.isProUser = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        return !result.userCancelled
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        guard isConfigured else { throw NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subscriptions unavailable"]) }
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        self.isProUser = info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - Gating Logic

    // Keys for the permanent weekly creation counter
    private static let nudgeCreationCountKey  = "nudge.weeklyCreations.count"
    private static let nudgeCreationWeekKey   = "nudge.weeklyCreations.weekStart"

    /// How many nudges the user has CREATED this week (never decrements on delete).
    func nudgesCreatedThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        let defaults = UserDefaults.standard
        if let storedWeekStart = defaults.object(forKey: Self.nudgeCreationWeekKey) as? Date,
           calendar.isDate(storedWeekStart, inSameDayAs: weekStart) {
            return defaults.integer(forKey: Self.nudgeCreationCountKey)
        } else {
            // New week — reset counter
            defaults.set(weekStart, forKey: Self.nudgeCreationWeekKey)
            defaults.set(0, forKey: Self.nudgeCreationCountKey)
            return 0
        }
    }

    /// Call once when a nudge is first saved. Increments the permanent counter.
    func recordNudgeCreated() {
        let current = nudgesCreatedThisWeek()
        UserDefaults.standard.set(current + 1, forKey: Self.nudgeCreationCountKey)
    }

    /// Legacy helper kept for CustomerCenterView display (reflects live entries).
    func nudgesThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return PersistenceManager.shared.entries.filter { $0.createdAt >= weekStart }.count
    }

    func canCreateNudge() -> Bool {
        if isProUser { return true }
        return nudgesCreatedThisWeek() < Self.freeNudgesPerWeek
    }

    var remainingFreeNudges: Int {
        max(0, Self.freeNudgesPerWeek - nudgesCreatedThisWeek())
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
